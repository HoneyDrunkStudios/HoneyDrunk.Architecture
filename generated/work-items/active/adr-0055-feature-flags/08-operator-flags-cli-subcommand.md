---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Operator
labels: ["feature", "tier-2", "ai", "cli", "adr-0055", "wave-5"]
dependencies: ["work-item:05"]
adrs: ["ADR-0055", "ADR-0018", "ADR-0030"]
wave: 5
initiative: adr-0055-feature-flags
node: honeydrunk-operator
---

# Add the `operator flags …` CLI subcommand and wire permission/operational flip audit events

## Summary
Add the `operator flags …` CLI subcommand to `HoneyDrunk.Operator` per ADR-0055 D11 — `list`, `show`, `enable`, `disable`, `expire`, `review-due` — backed by the Azure App Configuration management SDK for write operations and `IFeatureGate` (composed from `HoneyDrunk.FeatureFlags`) for read operations. Wire **permission and operational flip events to `HoneyDrunk.Audit`** per ADR-0055 D10 / ADR-0030; release-flag flips are logged via `HoneyDrunk.Pulse` only, not audited.

## Context
ADR-0055 D11 defines the operator surface as a `flags` subcommand on the Operator CLI:
- `operator flags list [--node <node>] [--category <cat>]` — list flags with current state per environment.
- `operator flags show <flag-name>` — detailed view: per-environment state, targeting rules, lifecycle metadata, last flip.
- `operator flags enable <flag-name> [--env <env>] [--tenant <tenant-id>] [--percentage <0–100>]` — enable a flag, optionally scoped. Permission/operational flips are audited per D10.
- `operator flags disable <flag-name> [--env <env>] [--tenant <tenant-id>]` — disable; same audit semantics.
- `operator flags expire <flag-name>` — for release flags only; marks the flag expired (triggers CI failure on next build).
- `operator flags review-due [--node <node>]` — list permission/operational flags past their `annual_review_due`.

`HoneyDrunk.Operator` is governed by **ADR-0018** (its own standup initiative, in progress at scoping time). At time of writing, Operator is Seed/v0.0.0; its standup is delivering the solution scaffold + the eight Operator-owned contracts. The CLI **shell** — the `dotnet` console host with a verb-based command surface — is part of ADR-0018's standup. **This packet depends on Operator's CLI shell being live.**

**Execution prerequisite:** before this packet can execute, ADR-0018's standup must have delivered enough of `HoneyDrunk.Operator` that a CLI shell exists with subcommand routing. If it has not, this packet is deferred. See Human Prerequisites. If the executor finds the shell exists but is only a minimal scaffold, the implementation here adds the `flags` verb cleanly alongside the existing scaffold — no contortion required.

The write surface — flipping App Configuration values — uses the **App Configuration management SDK** (`Azure.ResourceManager.AppConfiguration` + `Azure.Data.AppConfiguration`), authenticated via Managed Identity. Read operations use `IFeatureGate` for evaluation against the operator's principal context (handy for `show` — "what does this flag evaluate to right now for this tenant?"). The write path is direct; the read path goes through the contract for consistency with the rest of the Grid.

ADR-0055 D10 names the audit semantics precisely:
- **Permission flag flips ARE audit events** (per ADR-0030 `IAuditLog`).
- **Operational flag flips ARE audit events** (incident-bounded toggles are exactly what audit captures).
- **Release flag flips are LOGGED but NOT audited** (release-flag toggling is routine dev workflow; audit-logging it adds noise without value).

This packet wires the audit emission for permission/operational categories; release-category flips emit log events to Pulse only.

## Scope
- New `Flags` verb / subcommand handlers on the Operator CLI — six verbs (`list`, `show`, `enable`, `disable`, `expire`, `review-due`) under the `flags` group.
- App Configuration management SDK integration (read + write) — backing the verbs.
- `IFeatureGate` composition for the `show` verb's evaluate-against-context option.
- Audit emission via `HoneyDrunk.Audit.Abstractions`'s `IAuditLog` for permission/operational flips (ADR-0055 D10 / ADR-0030).
- Pulse log emission via the structured logger for every flip (release/permission/operational).
- New unit tests covering the verbs (each verb against a faked App Configuration client and a faked `IAuditLog`).
- Operator runbook documentation (a new section in the Operator README or `docs/runbook.md`) covering the flip workflow per category.
- Version bump per the Operator solution at execution time (per invariant 27).

## Proposed Implementation
1. **Confirm Operator's CLI shell exists at execution time.** Inspect `HoneyDrunk.Operator`'s solution: is there a `HoneyDrunk.Operator.Cli` executable (or similar) with a verb-routing surface? If yes, proceed. If no, this packet stops; record the gap as a hard dependency on ADR-0018 packet that adds the CLI shell, and re-file once the shell is shipped. The Human Prerequisites section calls this out.

2. **Pick the verb-routing framework.** Operator likely uses `System.CommandLine` or `Cocona` or `Spectre.Console.Cli` — match whatever the shell uses; do not introduce a new CLI framework here.

3. **Implement the six verbs.** Group them under `flags`:
   - **`operator flags list [--node <node>] [--category <cat>]`**
     - Read every `featureflags.json` discoverable from the Operator's known-Nodes registry (the Grid catalog is the source — Operator depends on `HoneyDrunk.Architecture/catalogs/` content or a structured Operator-side mirror).
     - For each flag, query App Configuration via the management SDK for the per-environment value (`dev`/`staging`/`prod`/`ci` labels).
     - Filter by `--node` (lowercase node segment in the flag name) and `--category` (`release`/`permission`/`operational`) if supplied.
     - Output a markdown table to stdout (the Operator CLI's convention — confirm against the shell's existing verbs).
   - **`operator flags show <flag-name>`**
     - Read the flag's `featureflags.json` entry (description, owner, created, expires_on, annual_review_due, tags, hotpath).
     - Read the flag's per-label state from App Configuration (enabled per env, targeting filters, last-flipped timestamp).
     - Optionally evaluate the flag against the operator's principal context using `IFeatureGate.IsEnabledAsync(name, principalContext)` to show the live decision.
   - **`operator flags enable <flag-name> [--env <env>] [--tenant <tenant-id>] [--percentage <0–100>]`**
     - Write the per-label App Configuration value to `enabled: true` (or with the supplied targeting filter shape).
     - Read the flag's category from `featureflags.json` to decide whether to emit an audit event (permission/operational yes; release no).
     - Emit an audit event via `IAuditLog` (see step 4) for permission/operational; emit a Pulse log event for every flip (release/permission/operational).
   - **`operator flags disable <flag-name> [--env <env>] [--tenant <tenant-id>]`**
     - Same as enable, but writes `enabled: false`. Same audit/log semantics.
   - **`operator flags expire <flag-name>`**
     - Read the flag from `featureflags.json`; verify `category: release` (else error — `expire` is release-only per D11).
     - Patch the registry's `expires_on` to today's date (the file lives in the Node's repo; this is a write-against-the-repo operation, not against App Configuration — see Cross-Cutting Concerns in the dispatch plan).
     - Optional: open a PR against the Node's repo with the patch; agent-driven, but human-reviewed.
     - Emit a Pulse log event; no audit (release-flag flips are not audited per D10).
   - **`operator flags review-due [--node <node>]`**
     - Read every `featureflags.json` from the catalog.
     - Filter to permission/operational flags whose `annual_review_due` is on or before today.
     - Output a markdown table; this is a read-only verb (no audit, no log emission beyond a routine Pulse event).

4. **Audit emission for permission/operational flips.** ADR-0055 D10 + ADR-0030:
   ```csharp
   await _auditLog.AppendAsync(new AuditEntry(
       category: AuditCategory.PolicyChange,
       action: enabled ? "feature_flag_enabled" : "feature_flag_disabled",
       principalId: requestContext.PrincipalId,
       targetType: "feature_flag",
       targetId: flagName,
       tenantId: requestContext.TenantId, // null for grid-wide flips; populated for tenant-scoped
       outcome: AuditOutcome.Success,
       changes: new AuditChanges {
           Previous = new { enabled = wasEnabled },
           Current = new { enabled = enabled, env = scope.Environment, tenant = scope.TenantId, percentage = scope.Percentage }
       }
   ));
   ```
   The exact `AuditEntry` shape is defined by `HoneyDrunk.Audit.Abstractions` v0.1.0 (already published — Audit is Live at v0.1.0). Confirm the API at edit time against the published version.

5. **Pulse log emission for every flip.** ADR-0055 D10 specifies the shape:
   ```json
   {
     "event": "feature_flag_flipped",
     "flag.name": "permission.lately.video-posts",
     "flag.category": "permission",
     "flag.previous_state": false,
     "flag.new_state": true,
     "operator.id": "prn-...",
     "scope.env": "prod",
     "scope.tenant": "tenant-...",
     "trace_id": "..."
   }
   ```
   Use `Microsoft.Extensions.Logging.ILogger` structured logging — Pulse's sink composition at the Operator host carries the events to App Insights per ADR-0040.

6. **Unit tests** — for each verb, against a faked App Configuration client (`Azure.Data.AppConfiguration.ConfigurationClient` substituted via NSubstitute), a faked `IAuditLog`, and a faked `IFeatureGate` for `show`. Assertions: the write happens with the right key/label/value; the audit event is emitted with the right category/action/target; the Pulse log event is emitted with the right structured fields; release flips emit log but NOT audit; permission/operational flips emit both.

7. **Operator runbook documentation** — add a "Feature Flags Operator Workflow" section to the Operator README or to a dedicated runbook doc. Cover: the verb reference, the audit semantics per category, the App Configuration permission model (Managed Identity Reader+Writer roles needed on the App Configuration resource for the verbs to work; document the role-assignment step as a portal prerequisite).

8. **Version bump.** Confirm Operator's current solution version at execution time. If Operator is at `0.0.0` (still in initial standup), this packet may be bundled with Operator's standup work. If Operator has shipped a `0.1.0` (or higher) baseline, this packet bumps the next minor. The minor-bump rule per invariant 27 applies.

## Affected Files
- The Operator CLI's `Flags` verb files (new, under whatever the shell's command-tree convention is — likely `src/HoneyDrunk.Operator.Cli/Commands/Flags/`).
- The Operator host composition — DI registration for the App Configuration management client, `IFeatureGate`, `IAuditLog`.
- The Operator runbook doc — new "Feature Flags Operator Workflow" section.
- The Operator test project — new unit tests for each verb.
- Every non-test `.csproj` in the Operator solution — version bump.
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md` for the packages with functional changes.

## NuGet Dependencies
- The Operator CLI / host project (whichever owns command composition):
  - `HoneyDrunk.Kernel.Abstractions` — for `IFeatureGate` (the read path).
  - `HoneyDrunk.FeatureFlags` — packet 05's published v0.1.0 (concrete `IFeatureGate` + composition).
  - `HoneyDrunk.Audit.Abstractions` — for `IAuditLog` (already a known dependency for Operator per ADR-0018; confirm version at edit time).
  - `Azure.Data.AppConfiguration` — App Configuration management SDK (write path).
  - `Azure.ResourceManager.AppConfiguration` — for higher-level management operations if needed (read flag state across labels; the higher-level SDK simplifies cross-label reads).
  - `Azure.Identity` — for `ManagedIdentityCredential` (the auth surface per ADR-0005).

## Boundary Check
- [x] `HoneyDrunk.Operator` is the correct repo per ADR-0055 D11.
- [x] Permission/operational flip audit events flow through `IAuditLog` (ADR-0030) — the right boundary.
- [x] Release flag flip events flow through Pulse logs only, not audit (ADR-0055 D10).
- [x] No new contract is added to `HoneyDrunk.Kernel.Abstractions` — the verbs consume existing contracts (`IFeatureGate`, `IAuditLog`).

## Acceptance Criteria
- [ ] Operator's CLI exposes six verbs under `operator flags`: `list`, `show`, `enable`, `disable`, `expire`, `review-due`, matching ADR-0055 D11 signatures
- [ ] `enable` and `disable` accept `--env`, `--tenant`, `--percentage` per D11; the targeting filter JSON written to App Configuration matches ADR-0055 D3's `TenantTargeting` filter shape when `--tenant` or tier filtering is used
- [ ] `expire` operates only on `category: release` flags; emits an error for permission/operational flags
- [ ] `review-due` reads every discoverable `featureflags.json` and lists permission/operational flags with `annual_review_due` on or before today
- [ ] **Permission and operational flips emit an audit event** via `IAuditLog` with category `PolicyChange`, action `feature_flag_enabled` / `feature_flag_disabled`, the principal/operator id, the flag name as the target, and the previous/new state in `changes`
- [ ] **Release flips do NOT emit audit events** — the audit pipeline is bypassed for release-category flags per ADR-0055 D10
- [ ] Every flip emits a Pulse log event (`feature_flag_flipped`) with the structured fields per ADR-0055 D10
- [ ] App Configuration writes use the management SDK with Managed Identity auth per ADR-0005 (no secret in code or config; invariants 8, 9)
- [ ] Unit tests cover each verb against faked App Configuration client + faked `IAuditLog`; the tests assert audit is emitted for permission/operational and NOT emitted for release (the negative assertion is critical)
- [ ] Operator runbook documents the verb reference, the audit semantics per category, and the Managed Identity role-assignment portal step
- [ ] Every non-test `.csproj` in the Operator solution is at the same new minor version in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new dated version entry; per-package CHANGELOGs only for packages with actual changes (invariant 12)
- [ ] No `Thread.Sleep` in tests (invariant 51); no external dependencies in tests (invariant 15)
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Operator's CLI shell must be live before this packet can execute.** ADR-0018's Operator-standup track delivers the shell. If the shell does not yet exist at this packet's execution time, this packet is deferred — close the issue with `wontfix-deferred` and a comment naming the ADR-0018 prerequisite, then re-file once the shell ships. The packet body assumes the shell exists.
- [ ] Packet 05's `HoneyDrunk.FeatureFlags` v0.1.0 must be published to NuGet before this packet's CLI host project can build.
- [ ] **Managed Identity role assignments on App Configuration** — the Operator Node's Managed Identity needs Reader (for `list`, `show`, `review-due`) and Data Contributor / Owner (for `enable`, `disable`) on the App Configuration resource(s) per environment. This is a portal step done as part of (or alongside) packet 03's walkthrough. Document the role assignment in this packet's runbook section and confirm it before the verbs are exercised in any environment.

## Referenced ADR Decisions
**ADR-0055 D11 — Operator surface: `operator flags …` CLI subcommand.** Six verbs (`list`, `show`, `enable`, `disable`, `expire`, `review-due`) with the signatures named in the ADR. The Operator Node reads and writes via the App Configuration SDK directly; the dependency is `HoneyDrunk.FeatureFlags.Abstractions` (or `HoneyDrunk.Kernel.Abstractions` for the contract surface per packet 04 — pick the one that's actually published) plus the App Configuration management SDK. All write operations capture `RequestContext.PrincipalId` for the audit record.

**ADR-0055 D10 — Permission-flag flips are audit events; operational-flag flips are also audited; release-flag flips are logged but not audited.** "These are quasi-authorization decisions (D8) and the audit substrate is the right surface for them. The audit record captures operator identity, tenant scope, previous/new state, and timestamp. Operational-flag flips are also audited (kill-switch usage during incidents is exactly the kind of event the post-mortem needs visibility into). Release-flag flips are logged but not audited — release-flag toggling is routine dev workflow and audit-logging it adds noise without value."

**ADR-0030 — Audit substrate.** Permission and operational flip events are emitted via `IAuditLog` from `HoneyDrunk.Audit.Abstractions`. The Audit record carries operator id, target type (`feature_flag`), target id (flag name), previous/new state, and timestamp.

**ADR-0018 — Operator standup.** This packet depends on Operator's CLI shell being live, which is delivered by the ADR-0018 standup track. If the shell is not yet shipped, this packet is deferred.

## Constraints
- **Operator's CLI shell is a hard prerequisite.** If absent, defer; do not author a parallel shell.
- **Audit asymmetry is hard.** Release-category flips MUST NOT emit audit events. The asymmetry is not subtle and not a runtime configuration — it is a code-path branch based on the flag's category. Unit tests assert both halves of the asymmetry (audit emitted for permission/operational; audit NOT emitted for release).
- **Managed Identity for write operations.** No connection string, no SAS key, no shared secret. Invariants 8, 9 apply.
- **`expire` is release-only.** Permission/operational don't expire (D7); calling `expire` on one is an error.
- **Tag/release is human.** Invariant 27. After this PR merges, a human tags the new Operator version; agents never tag.
- **Invariant 27 — solution-wide version bump.** Standard.

## Labels
`feature`, `tier-2`, `ai`, `cli`, `adr-0055`, `wave-5`

## Agent Handoff

**Objective:** Add the `operator flags …` CLI subcommand to `HoneyDrunk.Operator` with six verbs (list/show/enable/disable/expire/review-due), wire permission/operational flip audit events via `IAuditLog`, and emit Pulse log events for every flip.

**Target:** `HoneyDrunk.Operator`, branch from `main`. **Conditional on Operator's CLI shell being live — see Human Prerequisites.**

**Context:**
- Goal: Give the operator a low-friction surface for the daily-driver flag operations (listing, enabling, disabling, expiring, review-due) with the correct audit/log semantics per category.
- Feature: ADR-0055 Feature Flag rollout, Wave 5 (the operator surface).
- ADRs: ADR-0055 D10/D11 (primary), ADR-0030 (`IAuditLog`), ADR-0018 (Operator scaffold provides the CLI shell), ADR-0005 (App Configuration via Managed Identity), ADR-0026 (RequestContext for principal id in audit records).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:05` — `HoneyDrunk.FeatureFlags` v0.1.0 published; `IFeatureGate` composition available.

**Constraints:**
- Operator's CLI shell is a hard prerequisite (ADR-0018 standup).
- Audit asymmetry per category is hard: release no, permission/operational yes. Unit tests assert both halves.
- Managed Identity for write operations; no secret in code or config.
- `expire` is release-only.

**Key Files:**
- `src/HoneyDrunk.Operator.Cli/Commands/Flags/*.cs` (new) — the six verb handlers.
- Operator host composition — DI registration for `IFeatureGate`, `IAuditLog`, the App Configuration management client.
- Operator runbook — new "Feature Flags Operator Workflow" section.
- The test project — new unit tests for each verb.
- Every non-test `.csproj` in the solution — version bump (invariant 27).

**Contracts:**
- Consumes `IFeatureGate` from `HoneyDrunk.Kernel.Abstractions` (read path for `show`).
- Consumes `IAuditLog` from `HoneyDrunk.Audit.Abstractions` (permission/operational flips).
- Consumes the App Configuration management SDK (write path).
- Consumes `ILogger` for structured Pulse log emission.
