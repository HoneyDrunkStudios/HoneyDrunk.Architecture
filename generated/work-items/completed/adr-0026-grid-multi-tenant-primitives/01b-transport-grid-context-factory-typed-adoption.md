---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Transport
labels: ["chore", "tier-2", "core", "adr-0026", "wave-1"]
dependencies: ["Kernel#NN — Grid multi-tenant primitives (packet 01)"]
adrs: ["ADR-0026"]
wave: 1
initiative: adr-0026-grid-multi-tenant-primitives
node: honeydrunk-transport
coordinated_with: ["HoneyDrunk.Kernel", "HoneyDrunk.Data", "HoneyDrunk.Web.Rest", "HoneyDrunk.Pulse"]
---

# Chore: Adapt Transport GridContextFactory.InitializeFromEnvelope to Kernel 0.5.0 typed Initialize signature

## Summary
After the lead Kernel packet (#01) promotes `IGridContext.TenantId` to non-nullable `TenantId` and changes `GridContext.Initialize(...)`'s `tenantId` parameter from `string?` to typed `TenantId`, `HoneyDrunk.Transport/Context/GridContextFactory.cs` no longer compiles against published Kernel 0.5.0. This packet adapts the single callsite (line 50 today) by parsing the envelope's `string? TenantId` into the typed Kernel `TenantId`, defaulting to `TenantId.Internal` for absent / malformed values (warning-log on malformed, no throw — matches Kernel's messaging-mapper policy). **`ITransportEnvelope` shape is preserved** — its `TenantId` stays `string?` to keep wire-format stability across already-shipped Transport adapters (AzureServiceBus, StorageQueue, InMemory). Coordinated solution-wide minor bump on `HoneyDrunk.Transport` (`0.4.0 → 0.5.0`).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Transport`

## Motivation
ADR-0026 D2 promotes `IGridContext.TenantId` from `string?` to typed `TenantId`. The lead Kernel packet (#01) changes Kernel's runtime `GridContext.Initialize(string correlationId, string? causationId, TenantId tenantId, string? projectId, ...)` accordingly. Transport's `GridContextFactory.InitializeFromEnvelope` (file `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/Context/GridContextFactory.cs`, line 50) calls `kernelContext.Initialize(..., tenantId: envelope.TenantId, ...)` where `envelope.TenantId` is the string-typed property on `ITransportEnvelope`. After Kernel 0.5.0, this implicit `string? → TenantId` no longer compiles.

Two design choices the user surfaced and the recommendation:

1. **Promote `ITransportEnvelope.TenantId` from `string?` to typed `TenantId`** (parallel to Kernel's promotion). Pros: consistent typing across context primitives. Cons: it's a downstream-breaking change for every Transport adapter and every consumer that constructs envelopes today (AzureServiceBus, StorageQueue, InMemory, Tests, Sandbox), AND the wire format (the JSON / message-property shape Service Bus reads) stays string-based regardless. The wire/in-memory split would create per-adapter conversion noise.

2. **Adapt at the factory layer, keep `ITransportEnvelope.TenantId` as `string?`.** Pros: `ITransportEnvelope` stays a wire-shaped record; existing adapters are untouched; the only conversion happens at exactly one place (the factory, which is already the typed-Kernel-context boundary). Cons: the envelope and Kernel context have a typed-vs-string mismatch in the `TenantId` slot — but that mismatch is exactly what the factory's job is to bridge.

**Recommendation: choice 2.** Same-day Wave 1 motivation: the factory IS the one place that knows it's bridging wire-shaped Transport metadata into typed Kernel context. Adding a parse + Internal-default at that boundary is the minimal-surface-area change. `ITransportEnvelope.TenantId` promotion to typed `TenantId` becomes a follow-up packet if and when wire-shape changes in the future motivate it (PDR-0002 doesn't motivate it; Notify Cloud doesn't motivate it).

This packet ships the Transport half of the coordinated Wave 1.

## Proposed Implementation

### A. Adapt `GridContextFactory.InitializeFromEnvelope`

`HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/Context/GridContextFactory.cs`:

The current call site (line 47-54):
```csharp
kernelContext.Initialize(
    correlationId: correlationId,
    causationId: causationId,
    tenantId: envelope.TenantId,
    projectId: envelope.ProjectId,
    baggage: baggage,
    cancellation: cancellationToken);
```

The new shape:
```csharp
// Parse the envelope's string TenantId into Kernel's typed TenantId.
// Absent / malformed → Internal (matches Kernel's messaging-mapper policy:
// log warning, default to Internal, do not throw — a queued message cannot
// be 400'd back to the sender).
var tenantId = ParseTenantId(envelope.TenantId, _logger);

kernelContext.Initialize(
    correlationId: correlationId,
    causationId: causationId,
    tenantId: tenantId,
    projectId: envelope.ProjectId,
    baggage: baggage,
    cancellation: cancellationToken);
```

Add a private static helper at the bottom of the class:
```csharp
private static TenantId ParseTenantId(string? raw, ILogger<GridContextFactory>? logger)
{
    if (string.IsNullOrWhiteSpace(raw))
    {
        return TenantId.Internal;
    }

    if (TenantId.TryParse(raw, out var parsed))
    {
        return parsed;
    }

    // Malformed envelope tenant — warn and default to Internal (do NOT throw;
    // a queued / in-flight message cannot be rejected back to its sender).
    logger?.LogWarning(
        "Envelope carried a malformed TenantId; defaulting to Internal. " +
        "MessageId: {MessageId}", /* don't log the raw value — Invariant 8 */
        /* the caller passes context where helpful */);

    return TenantId.Internal;
}
```

The factory currently has no constructor-injected `ILogger`. Add one (`GridContextFactory(ILogger<GridContextFactory> logger)`) and inject `null`-tolerant — make the constructor accept `ILogger<GridContextFactory>? logger = null` so existing test fixtures that `new GridContextFactory()` keep working. Update the DI registration in `HoneyDrunk.Transport/Extensions/` (or wherever the factory is registered as `IGridContextFactory`) to inject the typed logger.

Add `using HoneyDrunk.Kernel.Abstractions.Identity;` to the file's using block so the unqualified `TenantId` resolves.

The XML doc on `InitializeFromEnvelope` updates to mention: *"After Kernel 0.5.0, the envelope's `TenantId` (string-typed) is parsed into Kernel's typed `TenantId` at this boundary. Absent or malformed values default to `TenantId.Internal` and emit a warning log; the request proceeds rather than throw, because a queued message cannot be rejected back to its sender."*

### B. Do NOT modify `ITransportEnvelope`

Per the Motivation section's recommendation, `ITransportEnvelope.TenantId` stays `string?`. This is the wire-shape boundary — adapters serialize from / deserialize to a string property regardless of how the in-process Kernel typing evolves. Keeping the contract stable here:
- Avoids forcing every Transport adapter (AzureServiceBus, StorageQueue, InMemory) to bump its own version on wire-shape grounds.
- Keeps already-emitted messages on the queue forward-compatible — a Notify worker reading a Service Bus message that was enqueued by a previous Notify version reads the same `tenant-id` message-property string regardless of consumer's Kernel version.
- Localizes the typed-vs-wire conversion to exactly one place (this factory), which is its job.

Cross-check at execution: `git diff HoneyDrunk.Transport/Abstractions/ITransportEnvelope.cs` MUST be empty. If a different design choice is preferred at PR review (promote envelope to typed), that is a follow-up packet, not this one — surface the proposal in the PR description and proceed with the wire-stable shape for this Wave 1 merge.

### C. Verify no other Kernel-context callsites in Transport need adaptation

Run at execution: `rg "context\.TenantId|gridContext\.TenantId|operationContext\.TenantId|envelope\.TenantId" --type cs` across the Transport repo. The packet authoring grep shows `GridContextFactory.cs` line 50 as the only callsite that transitively reaches Kernel's typed `TenantId` parameter. If new callsites have appeared since packet authoring, apply the same parse-with-Internal-default pattern.

### D. Coordinated version bump

Per Invariant 27, every project in the `HoneyDrunk.Transport` solution moves to `0.5.0`:
- `HoneyDrunk.Transport/HoneyDrunk.Transport` — actual change (this packet's adapter)
- `HoneyDrunk.Transport.AzureServiceBus` — alignment-only
- `HoneyDrunk.Transport.StorageQueue` — alignment-only
- `HoneyDrunk.Transport.InMemory` — alignment-only
- `HoneyDrunk.Transport.SandboxNode` — alignment-only
- `HoneyDrunk.Transport.Tests` — test project

Bump the `<Version>` in each `.csproj` from `0.4.0` to `0.5.0`. Bump the `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` `<PackageReference>` versions from `0.4.0` to `0.5.0` in every `.csproj` that references them (verified target: `HoneyDrunk.Transport.csproj`).

Per Invariant 12 — repo-level `CHANGELOG.md` gets a new `0.5.0` entry covering the typed-`TenantId` adoption at the factory boundary. Per-package `CHANGELOG.md` updates ONLY for `HoneyDrunk.Transport/` (the package with actual change). The four sibling provider packages and the test project get NO per-package CHANGELOG entries (alignment-only — Invariant 12 prohibits noise entries).

### E. Tests

Update or add tests in `HoneyDrunk.Transport.Tests/Context/GridContextFactoryTests.cs` (or wherever the factory tests live):

1. **Envelope with no TenantId → context populated with `TenantId.Internal`.** Construct an envelope with `TenantId = null`. Assert the resulting `gridContext.TenantId.IsInternal == true`.

2. **Envelope with valid ULID-string TenantId → context populated with the parsed typed value.** Construct an envelope with `TenantId = TenantId.NewId().ToString()`. Assert the resulting `gridContext.TenantId.ToString()` equals the input string.

3. **Envelope with malformed TenantId → context populated with Internal AND a warning is logged.** Construct an envelope with `TenantId = "not-a-ulid"`. Assert the resulting `gridContext.TenantId.IsInternal == true`. Assert (via a captured logger) that exactly one warning was emitted referencing the messageId. Assert the warning does NOT contain the raw "not-a-ulid" string in its message template (Invariant 8 — values not logged; the structured-log argument may carry it, but the message template should reference messageId only).

4. **Envelope-with-Internal-string TenantId is treated as Internal.** Construct an envelope with `TenantId = "00000000000000000000000000"`. Assert the resulting `gridContext.TenantId.IsInternal == true` (the parse + `IsInternal` check naturally handles this case; the test pins the symmetry).

Existing factory tests that constructed envelopes with non-`TenantId` payloads still pass — the Initialize signature change is the only consumer-visible difference.

### F. README touch-up

If `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/README.md` has a code example showing envelope construction or `InitializeFromEnvelope` usage, update the example to show how typed Kernel `TenantId` is populated in context after the parse. Do NOT include the ADR ID. If no example references tenancy, no edit needed.

## Affected Files

- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/Context/GridContextFactory.cs` (edit — line 50 area; add `ParseTenantId` helper; constructor-inject optional `ILogger`)
- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/Extensions/` — DI registration of the factory updated to inject the typed logger (locate the existing `Add*` extension at execution; one-line change)
- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/Abstractions/ITransportEnvelope.cs` — **READ-ONLY for reference; do NOT edit**. Wire-shape preservation is the design decision.
- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport.Tests/Context/GridContextFactoryTests.cs` (new or edit — four tests per section E)
- All `.csproj` files in the Transport solution (version bump `0.4.0 → 0.5.0`)
- `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` PackageReference versions in every `.csproj` that references them — bump to `0.5.0`
- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/CHANGELOG.md` (per-package — actual change)
- Repo-root `CHANGELOG.md` — new `0.5.0` entry
- Per-package `CHANGELOG.md` for non-changed packages — NO entries (Invariant 12)
- Per-package `README.md` for `HoneyDrunk.Transport/` — only if existing examples reference the now-obsolete `string?` flow

## NuGet Dependencies

- `HoneyDrunk.Kernel` PackageReference: bump from `0.4.0` to `0.5.0` (the version produced by Wave 1 packet 01).
- `HoneyDrunk.Kernel.Abstractions` PackageReference: bump from `0.4.0` to `0.5.0`.

No new package additions. Optional: `Microsoft.Extensions.Logging.Abstractions` is already referenced in `HoneyDrunk.Transport.csproj` so the logger-injection works without adding a new dependency.

## Boundary Check
- [x] All edits in `HoneyDrunk.Transport`. Routing rule "transport, messaging, service bus, queue, broker, envelope, dispatcher" → `HoneyDrunk.Transport` matches.
- [x] **No change to `ITransportEnvelope` contract.** Wire-shape stability preserved per the Motivation section's design decision. Verify with `git diff HoneyDrunk.Transport/Abstractions/`.
- [x] No change to `IGridContextFactory` interface — `InitializeFromEnvelope` signature unchanged; only the body adapts.
- [x] No change to provider packages (AzureServiceBus, StorageQueue, InMemory) — they neither construct envelopes nor call into Kernel's typed `Initialize` directly.
- [x] Honors Kernel's messaging-mapper policy (warning-log + Internal default on malformed; do not throw on a queued message).
- [x] Honors Invariant 8 — the warning-log message template references `messageId` only; the raw malformed string is not put in the template (may appear in a structured-log argument but not in the human-readable message).
- [x] Honors Invariant 5 — `gridContext` is a Kernel-owned scoped instance; Transport initializes it from envelope metadata as today.
- [x] No new transitive runtime dependencies (Invariant 2). Already depends on `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions`.

## Acceptance Criteria

- [ ] `GridContextFactory.InitializeFromEnvelope` compiles against published `HoneyDrunk.Kernel` 0.5.0 + `HoneyDrunk.Kernel.Abstractions` 0.5.0.
- [ ] The factory parses `envelope.TenantId` (string?) into a typed `Kernel.TenantId` via `TenantId.TryParse` with `TenantId.Internal` defaulting on absent / malformed.
- [ ] Malformed envelope tenants log a warning (no throw) referencing `messageId` (NOT the raw malformed string in the template — Invariant 8).
- [ ] `GridContextFactory` constructor accepts an optional `ILogger<GridContextFactory>?` parameter (default `null` for test-fixture back-compat).
- [ ] DI registration in `HoneyDrunk.Transport/Extensions/` injects the typed logger.
- [ ] **`ITransportEnvelope.TenantId` remains `string?`.** Verify with `git diff HoneyDrunk.Transport/Abstractions/ITransportEnvelope.cs` — diff must be empty.
- [ ] **`IGridContextFactory.InitializeFromEnvelope` signature unchanged.** Verify with `git diff HoneyDrunk.Transport/Abstractions/` — diff must be empty.
- [ ] Four new / updated tests in `GridContextFactoryTests.cs` (no tenant → Internal; valid ULID → typed value; malformed → Internal + warning + no value-in-template; Internal-string → Internal) pass.
- [ ] Existing factory tests still pass.
- [ ] Every `.csproj` in the Transport solution moves from `0.4.0` to `0.5.0` in a single commit (Invariant 27).
- [ ] `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` PackageReference versions in every Transport `.csproj` that references them are bumped to `0.5.0`.
- [ ] Repo-level `CHANGELOG.md` has a new `0.5.0` entry covering the Kernel 0.5.0 adoption + the parse-with-default policy.
- [ ] Per-package `CHANGELOG.md` for `HoneyDrunk.Transport/` updated. No entries for `AzureServiceBus`, `StorageQueue`, `InMemory`, `SandboxNode`, `Tests` (alignment-only — Invariant 12).
- [ ] All canary tests green; full unit-test suite green.
- [ ] No public-API surface change to `ITransportEnvelope` or `IGridContextFactory`.

## Human Prerequisites
- [ ] **Confirm packet 01 (Kernel) merged AND `HoneyDrunk.Kernel` 0.5.0 + `HoneyDrunk.Kernel.Abstractions` 0.5.0 published.** Hard gate.
- [ ] **Confirm wire-shape design choice at PR review.** This packet keeps `ITransportEnvelope.TenantId` as `string?` (wire-stable; the typed conversion happens at the factory). The alternative — promote the envelope's TenantId to typed — is documented in the Motivation section and rejected on cost grounds. If you prefer the alternative at PR review, that becomes a follow-up packet (not this one); this packet's recommendation is wire-stable.
- [ ] **Coordinated merge in Wave 1.** This packet's PR merges within the same wave as Kernel 0.5.0. Dispatch operator coordinates merge order: Kernel first, then this packet (alongside Data, Web.Rest, Pulse).
- [ ] No portal / Azure work. NuGet-only library packet.

## Dependencies
- **Kernel#NN — Grid multi-tenant primitives (packet 01).** Hard. Kernel 0.5.0 must be published before this packet's PR builds green.

## Downstream Unblocks
- Wave 1 closure — once this packet merges (alongside the other Wave 1 sister packets), Kernel 0.5.0 has working consumers and Wave 2 (Vault) can begin.
- Notify, Communications, and Notify Cloud (PDR-0002) inherit the typed Kernel `TenantId` propagation across messaging hops automatically.

## Referenced Invariants

> **Invariant 2 (Dependency):** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. **Why it matters here:** Only the existing Kernel/Kernel.Abstractions reference versions move; no new package edges introduced.

> **Invariant 5 (Context):** GridContext must be present in every scoped operation. **Why it matters here:** Transport initializes the Kernel-owned scoped `gridContext` from envelope metadata; the typed `TenantId` is part of that contract.

> **Invariant 8 (Secrets & Trust):** Secret values never appear in logs, traces, exceptions, or telemetry. **Why it matters here:** The malformed-tenant warning's message template references `messageId` only, not the raw malformed string. (TenantIDs are not secret values per se, but this discipline keeps log-template content predictable and avoids accidental low-cardinality blowups in log search.)

> **Invariant 12 (Packaging):** Semantic versioning with CHANGELOG and README — repo-level mandatory; per-package only when the package has functional changes. **Why it matters here:** Repo-level `CHANGELOG.md` gets a `0.5.0` entry; only `HoneyDrunk.Transport/` gets a per-package entry.

> **Invariant 13 (Packaging):** All public APIs have XML documentation. **Why it matters here:** Updated XML doc on `InitializeFromEnvelope` describes the new parse-with-default behavior.

> **Invariant 26 (Work Tracking):** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.

> **Invariant 27 (Versioning):** All projects in a solution share one version and move together.

> **Invariant 31 (Code Review):** Every PR traverses the tier-1 gate before merge.

> **Invariant 32 (Code Review):** Agent-authored PRs must link to their packet in the PR body.

## Referenced ADR Decisions

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **D2 — `IGridContext.TenantId` is promoted from `string?` to `TenantId` (non-nullable).** Transport's factory adapts at the boundary because Kernel's `Initialize(...)` parameter is now typed.
- **D3 — Cross-Node propagation: messaging hop → mapper round-trips TenantId via the existing baggage / message-properties channel.** Transport sits at this boundary; the parse-with-Internal-default at the factory is the symmetric cousin of Kernel's `MessagingContextMapper` policy.
- **D9 — Coordinated Wave 1.** This packet is one of four downstream sister packets in Wave 1 (Data, Transport, Web.Rest, Pulse).
- **Negative consequences — blast radius inventory.** ADR-0026 names `Transport/Context/GridContextFactory.cs` line 50 as one of the four file-level callsites that need adaptation.

## Constraints

- **Do NOT modify `ITransportEnvelope`.** Wire-shape stability is the load-bearing design decision (see Motivation). Verify with `git diff HoneyDrunk.Transport/Abstractions/`.
- **Do NOT modify `IGridContextFactory` interface.** `InitializeFromEnvelope` signature stays the same; only the body adapts.
- **Warning-log on malformed; no throw.** Symmetric with Kernel's messaging-mapper policy. A queued message cannot be rejected back to its sender.
- **Warning-log message template references `messageId` only.** The raw malformed string may appear as a structured-log property argument (so an operator can grep for it later) but NOT in the human-readable template (Invariant 8 discipline).
- **Logger is optional via constructor.** `ILogger<GridContextFactory>? logger = null` — keeps existing test fixtures (`new GridContextFactory()`) compiling.
- **No new NuGet dependencies.** Kernel/Kernel.Abstractions versions move; nothing else added.
- **No ADR ID in code comments / README.**
- **Coordinated bump on every `.csproj`.** Provider/sub-package CHANGELOGs stay quiet (Invariant 12); only `HoneyDrunk.Transport/` gets a per-package entry.

## Labels
`chore`, `tier-2`, `core`, `adr-0026`, `wave-1`

## Agent Handoff

**Objective:** Adapt `HoneyDrunk.Transport.Context.GridContextFactory.InitializeFromEnvelope` to Kernel 0.5.0's typed `Initialize(...)` signature. Preserve `ITransportEnvelope` wire shape. Coordinated solution-wide bump to `0.5.0`. Sister packet to lead Kernel packet (#01) in Wave 1.

**Target:** `HoneyDrunk.Transport`, branch from `main`.

**Context:**
- Goal: Add a parse-with-Internal-default at the typed-Kernel boundary; preserve wire-shape stability on `ITransportEnvelope`.
- Feature: ADR-0026 Grid Multi-Tenant Primitives, Wave 1 (coordinated multi-repo bump).
- ADRs: ADR-0026 (multi-tenant primitives, D2 + D3 + D9 + Negative Consequences blast radius).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Kernel#NN — Grid multi-tenant primitives (packet 01). Hard. Kernel 0.5.0 published before this PR builds.

**Constraints:** Per Constraints section above. Specifically:
- `ITransportEnvelope` unchanged.
- `IGridContextFactory` signature unchanged.
- Warning-log + Internal default on malformed; no throw.
- Log template references messageId only; raw value never in template.
- Coordinated `0.4.0 → 0.5.0` bump on every Transport `.csproj`. Per-package CHANGELOG only for `HoneyDrunk.Transport/`.
- No ADR ID in code / README.

**Inlined Invariant Text (for review without leaving the target repo):**

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer.

> **Invariant 5:** GridContext must be present in every scoped operation.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. (Applied here as log-template discipline — raw potentially-malformed user input does not belong in the human-readable template.)

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level mandatory; per-package only when the package has functional changes.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.

> **Invariant 27:** All projects in a solution share one version and move together.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

**Key Files:**
- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/Context/GridContextFactory.cs`
- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/Abstractions/ITransportEnvelope.cs` (READ-ONLY; do NOT edit)
- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport/Extensions/` — DI registration (locate at execution)
- `HoneyDrunk.Transport/HoneyDrunk.Transport/HoneyDrunk.Transport.Tests/Context/GridContextFactoryTests.cs` (new or edit)
- All `.csproj` files in the Transport solution
- Per-package `CHANGELOG.md` for `HoneyDrunk.Transport/` only
- Repo-root `CHANGELOG.md`

**Contracts:**
- No change to `ITransportEnvelope` (`HoneyDrunk.Transport.Abstractions.ITransportEnvelope.TenantId` stays `string?`).
- No change to `IGridContextFactory.InitializeFromEnvelope` signature.
- Internal: `GridContextFactory` constructor gains optional `ILogger<GridContextFactory>?` parameter; body parses envelope's string TenantId into Kernel's typed `TenantId` with `Internal` default on absent / malformed.
