# Dispatch Plan: ADR-0026 Grid Multi-Tenant Primitives

**Date:** 2026-05-02 (initial); revised 2026-05-02 after refine round (coordinated Wave 1 across five Nodes per ADR-0026 D9)
**Trigger:** ADR-0026 (Grid Multi-Tenant Primitives) Proposed — settles `TenantId` promotion, `Internal` sentinel, `ITenantRateLimitPolicy`, `IBillingEventEmitter`, per-tenant Vault scoping pattern, `tenant_id` Pulse telemetry discipline, and the multi-tenant boundary invariant.
**Type:** Multi-repo (six target repos across three waves)
**Sector:** Core (Kernel, Data, Transport, Web.Rest, Vault) · Ops (Pulse) · Meta (Architecture)
**Site sync required:** No (no public-facing surface change; site catalogs auto-import from `catalogs/contracts.json` and `catalogs/grid-health.json` on next Studios build).
**Rollback plan:**
- **Wave 1 — coordinated five-Node bump.** The shared blast radius is the typed `IGridContext.TenantId` / `IOperationContext.TenantId` promotion in Kernel 0.5.0. If any one of the five Wave 1 PRs fails review, hold the entire wave (do not merge Kernel alone — that creates a transient broken-restore window for the four downstream Nodes). Rollback shape: revert each merged PR in reverse order. Kernel's revert is the load-bearing one because the four downstream PRs depend on the typed shape.
- Packet 02 (Vault) is purely additive (new doc + new resolver + version bump). Rollback: revert the PR; the resolver is removed but `ISecretStore` is unchanged.
- Packet 04 (Architecture) is docs only. Rollback: revert the PR; ADR-0026 returns to Proposed, invariant 37 is removed, catalog regresses. No runtime impact.

## Summary

ADR-0026 makes multi-tenancy a Grid-wide primitive concern rather than a Notify Cloud-specific code path. The seven-packet rollout (across three waves, six target repos):

**Wave 1 — coordinated bump across Kernel + four downstream Nodes** (per ADR-0026 D9 revised):

1. **Kernel (packet 01).** Lead PR. Promotes `IGridContext.TenantId` AND `IOperationContext.TenantId` from `string?` to non-nullable `TenantId`. Adds `TenantId.Internal` sentinel (`00000000000000000000000000` — verified with Cysharp Ulid 1.4.1 runtime probe; equivalent to `Ulid.MinValue`) + `IsInternal` predicate (canary-pinned). Adds the `Tenancy` namespace to `HoneyDrunk.Kernel.Abstractions` with **five new surfaces**: `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `TenantRateLimitOutcome` enum, `IBillingEventEmitter`, `BillingEvent`. Ships `NoopTenantRateLimitPolicy` and `NoopBillingEventEmitter` defaults in `HoneyDrunk.Kernel`. Updates `GridContextMiddleware`, `HttpContextMapper`, `GridContextInitValues`, the runtime `GridContextFactory.CreateChild`, `MessagingContextMapper`, `JobContextMapper`, `OperationContext`, and `GridContextSerializer` to apply the `Internal` default at Grid entry. Documents the canary obligation for future implementations in the per-package README. Coordinated `0.4.0 → 0.5.0` minor bump on Kernel + Kernel.Abstractions per Invariant 27.

2. **Data (packet 01a).** Adapts `KernelTenantAccessor.GetCurrentTenantId()` to consume the typed Kernel `TenantId`; `IsInternal` translates to Data's `default` `TenantId`. Coordinated `0.4.0 → 0.5.0` bump.

3. **Transport (packet 01b).** Adapts `GridContextFactory.InitializeFromEnvelope` to parse the envelope's string-typed `TenantId` into Kernel's typed `TenantId` with Internal-default-on-malformed (warning log, no throw — symmetric with Kernel's messaging-mapper policy). **`ITransportEnvelope.TenantId` stays `string?`** — wire-shape stability preserved. Coordinated `0.4.0 → 0.5.0` bump.

4. **Web.Rest (packet 01c).** Adapts `RequestLoggingScopeMiddleware.EnrichWithKernelContext` to use `IsInternal` predicate; default omit-when-Internal log-scope discipline (symmetric with Pulse). Surfaces design choice for human PR review. Coordinated `0.3.0 → 0.4.0` bump.

5. **Pulse (packet 03).** Adapts `ActivityEnricher` and the Collector enrichers. Replaces `string.IsNullOrEmpty` checks with `IsInternal` short-circuit at the source. Adds a cardinality discipline doc anchored on PDR-0002 §K (paying customers measured in tens at v1; alarm at 200 distinct tenant IDs / 24h). Coordinated `0.1.0 → 0.2.0` bump on the Pulse solution.

**Wave 2 — Vault tenancy resolver:**

6. **Vault (packet 02).** Adds `HoneyDrunk.Vault/docs/Tenancy.md` documenting the `tenant-{tenantId}-{secretName}` convention (and the telemetry-of-tenant-scoped-secret-names policy: tenant ULIDs in identifiers are intentional for operational correlation, internal-only telemetry surface). Adds `TenantScopedSecretResolver` to the Vault runtime as a thin composition over `ISecretStore`. **No contract change to `ISecretStore`.** Coordinated `0.3.0 → 0.4.0` bump.

**Wave 3 — Architecture acceptance:**

7. **Architecture (packet 04).** Appends multi-tenant boundary invariant (37) to `constitution/invariants.md`. Adds catalog entries for the five new Kernel surfaces in `catalogs/contracts.json`. Updates `catalogs/grid-health.json` version fields for Kernel + Vault + Data + Transport + Web.Rest + Pulse and Kernel's `notes`. Updates `repos/HoneyDrunk.Kernel/boundaries.md` + `invariants.md` and `repos/HoneyDrunk.Vault/boundaries.md`. Adds D7-enforcement checklist line to `copilot/issue-authoring-rules.md` (manual enforcement until the static analyzer ships per ADR-0026 Open Questions §2). Flips ADR-0026 Status from Proposed to Accepted. Records initiative completion in `active-initiatives.md`. Pragmatic acceptance reading: flips Status when Wave 1 hard packets (01 + 01a + 01b + 01c) + Wave 2 (02) land; Pulse (03) can be in-flight in `active-initiatives.md` as an open checkbox.

The two changes from PDR-0002 §F that are NOT primitive-shaped (per-tenant API keys, multi-tenant Web.Rest auth path) are explicitly out of this initiative — they live in the Notify Cloud standup ADR + an Auth-side ADR and are scoped separately.

## Execution Model

Sequenced by ADR-0026 D9 (revised) — strict ordering between waves; coordinated within Wave 1.

**Wave 1 internal order.** Within Wave 1, the five PRs ship in a tight coordinated wave (typically same day):
- The **Kernel PR (packet 01) merges first** within Wave 1 so the resulting `HoneyDrunk.Kernel.Abstractions` 0.5.0 + `HoneyDrunk.Kernel` 0.5.0 publish to the Grid's NuGet feed.
- The four downstream PRs (Data 01a, Transport 01b, Web.Rest 01c, Pulse 03) merge in any order **as soon as their builds are green against the published Kernel 0.5.0 packages.**
- This avoids a transient broken-restore window for the four downstream Nodes — at no point does a consumer try to restore Kernel 0.5.0 without its own matching patch.
- Operationally, file all five Wave 1 packets at once; merge Kernel first; trigger downstream PR builds; merge each downstream PR as it goes green.

Within Wave 2 (just packet 02), there is no parallelism — Vault is one repo.

Wave 3 (packet 04) sits strictly after Wave 1 hard packets + Wave 2 publish.

Manual dispatch on Codex Cloud expected — packet 01 is a Tier 3 cross-repo change (breaking change on `IGridContext.TenantId` and `IOperationContext.TenantId`) that warrants human PR review before downstream packets begin. Filing is gated: file Wave 1 first (all five at once), wait for Kernel merge + publish, trigger downstream rebuilds, merge each as green; then file Wave 2; then file Wave 3.

### Wave 1 — coordinated multi-Node bump (file all five at once; merge Kernel first; downstream merges follow as green)

- [ ] `HoneyDrunk.Kernel`: Grid multi-tenant primitives — typed `TenantId` (on both `IGridContext` and `IOperationContext`), `Internal` sentinel `00000000000000000000000000`, four contracts, noop defaults, mapper/middleware/serializer/factory adoption, README canary obligation note, coordinated 0.5.0 bump — [`01-kernel-multi-tenant-primitives.md`](01-kernel-multi-tenant-primitives.md)
- [ ] `HoneyDrunk.Data`: Adapt `KernelTenantAccessor` to typed `IOperationContext.TenantId`; coordinated 0.5.0 bump — [`01a-data-tenant-accessor-typed-adoption.md`](01a-data-tenant-accessor-typed-adoption.md)
- [ ] `HoneyDrunk.Transport`: Adapt `GridContextFactory.InitializeFromEnvelope` to typed `Initialize` signature with parse-with-Internal-default; preserve `ITransportEnvelope` wire shape; coordinated 0.5.0 bump — [`01b-transport-grid-context-factory-typed-adoption.md`](01b-transport-grid-context-factory-typed-adoption.md)
- [ ] `HoneyDrunk.Web.Rest`: Adapt `RequestLoggingScopeMiddleware` to typed `TenantId` with omit-when-Internal log-scope discipline (default; confirm at PR review); coordinated 0.4.0 bump — [`01c-web-rest-request-logging-scope-typed-adoption.md`](01c-web-rest-request-logging-scope-typed-adoption.md)
- [ ] `HoneyDrunk.Pulse`: Adopt typed `TenantId` in `ActivityEnricher` + Collector; cardinality discipline doc; coordinated 0.2.0 bump — [`03-pulse-tenant-id-telemetry-tag.md`](03-pulse-tenant-id-telemetry-tag.md)

**Wave 1 exit criteria:**
- All five PRs merged to `main`.
- `HoneyDrunk.Kernel.Abstractions` 0.5.0 + `HoneyDrunk.Kernel` 0.5.0 published to the Grid's NuGet feed first.
- `HoneyDrunk.Data` 0.5.0, `HoneyDrunk.Transport` 0.5.0, `HoneyDrunk.Web.Rest.AspNetCore` 0.4.0, Pulse packages 0.2.0 all published immediately after.
- Canary tests green (contract-shape canary on the four new surfaces; `TenantId.Internal` literal pinning canary at `00000000000000000000000000`; noop default behavior canaries).
- Adapter tests green in each downstream repo (Data — `KernelTenantAccessor`; Transport — `GridContextFactory` parse-with-default; Web.Rest — log-scope omit-when-Internal; Pulse — `ActivityEnricher` Internal short-circuit).
- All canary suites green across the workspace.

### Wave 2 — Vault tenant-scoped secret resolver (file after Wave 1 publishes)

- [ ] `HoneyDrunk.Vault`: Per-tenant secret scoping pattern + `TenantScopedSecretResolver` + `docs/Tenancy.md` (with telemetry-of-tenant-scoped-secret-names section) + 0.4.0 bump — [`02-vault-tenant-scoped-secret-resolver.md`](02-vault-tenant-scoped-secret-resolver.md)

**Wave 2 exit criteria:**
- Vault PR merged to `main`.
- `HoneyDrunk.Vault` 0.4.0 published.
- Test suite green.
- `git diff HoneyDrunk.Vault/Abstractions/` is empty (no `ISecretStore` change).

### Wave 3 — Architecture acceptance (file after Wave 1 hard packets + Wave 2 publish; Pulse may still be in-flight per pragmatic reading)

- [ ] `HoneyDrunk.Architecture`: Catalog updates (contracts.json + grid-health.json) + invariant 37 + per-repo boundary refresh + issue-authoring-rules.md D7-enforcement line + ADR-0026 Status flip to Accepted — [`04-architecture-catalog-invariant-acceptance.md`](04-architecture-catalog-invariant-acceptance.md)

**Wave 3 exit criteria:**
- Wave 3 PR merged to `main`.
- ADR-0026 status header reads `Accepted`.
- `constitution/invariants.md` includes invariant 37 (or whatever number was assigned at execution — verify before merge).
- `catalogs/contracts.json` includes the five new Kernel-Tenancy entries and validates as well-formed JSON (`jq` check).
- `catalogs/grid-health.json` Kernel + Vault + Data + Transport + Web.Rest + Pulse versions match the on-disk `.csproj` values; validates as well-formed JSON.
- `copilot/issue-authoring-rules.md` Quality Checks block has the D7-enforcement checklist line.
- `initiatives/active-initiatives.md` has an ADR-0026 entry showing Wave 1 hard packets + Vault + Architecture rows checked, Pulse row checked or noted as open.

**Acceptance reading (pragmatic vs strict):** Default behavior is **pragmatic** — flip Status to Accepted when Wave 1 hard packets (01 + 01a + 01b + 01c) + Vault land. Pulse (03) is consumer-side telemetry adoption and does not affect the primitive contracts; ADR-0026 D9 explicitly says consumer-Node adoption proceeds under its own packets. The strict reading (wait for Pulse to merge before flipping) is defensible — choose at PR review on packet 04. The packet defaults to pragmatic and tracks Pulse as an open checkbox in `active-initiatives.md` if it hasn't merged.

## Open Bikeshed (Resolved)

Per ADR-0026 Open Questions §3 and memory `project_human_only_convention`, the `TenantId.Internal` ULID literal was bikeshed-shaped at ADR drafting. **Resolved at packet authoring with a runtime probe: the literal is `00000000000000000000000000` (the canonical zero ULID, equivalent to `Ulid.MinValue` in Cysharp Ulid 1.4.x).** Verified: `Ulid.TryParse("00000000000000000000000000", out _)` returns `true` and the value round-trips through `ToString()` to the same canonical form. `Ulid.NewUlid()` cannot produce it in practice (the first 48 bits encode unix-timestamp-ms; a 1970-epoch clock is impossible in production). The human (oleg@honeydrunkstudios.com) confirms at PR review on packet 01; once merged, the canary pins it for the lifetime of the type.

The four packets all default to `Actor=Agent`. None receive the `human-only` label.

A second design choice surfaces in **packet 01c (Web.Rest)** for human PR review — the `TenantId` log-scope entry can either always emit (including the Internal sentinel) or omit-when-Internal. The packet defaults to omit-when-Internal (symmetric with Pulse's discipline) but flags the choice.

## Out of Scope (Explicitly Deferred to Other ADRs / Packets)

Per ADR-0026 D10 and the user's framing:

- **Per-tenant API key issuance, validation, storage.** Notify Cloud + Auth concern. Separate "API key authentication pattern ADR" (PDR-0002 §Recommended Follow-Up Artifacts).
- **Multi-tenant Web.Rest auth path.** Same — Auth-and-Notify-Cloud concern.
- **Rate-limit storage backend (Redis / Azure Storage Tables / etc.).** Notify Cloud picks during its standup ADR.
- **Billing-event queue topology, Stripe webhook bridge.** `HoneyDrunk.Notify.Cloud.Billing.Stripe` packet — separate ADR.
- **Project-scoped tenancy (`ProjectId` promotion).** Future ADR; Notify Cloud v1 is per-tenant, not per-project. `IOperationContext.ProjectId` and `IGridContext.ProjectId` stay `string?` in Wave 1.
- **Tenant abuse detection, fraud signals, automatic pause.** Operations concerns — surfaced via Pulse, not primitives.
- **Multi-region tenancy.** Notify Cloud v1 is single-region.
- **Static analyzer that flags `ITenantRateLimitPolicy` references inside `Routing/`, `Worker/`, or `Providers/` folders.** Future `HoneyDrunk.Standards` packet (ADR-0026 Open Questions §2). Wave 3 ships a manual-enforcement checklist line in `copilot/issue-authoring-rules.md` as the bridge.
- **Test fixtures for tenancy (`HoneyDrunk.Kernel.Testing` companion).** Future packet — defer until the first consumer asks for it. Wave 1 packet 01 documents the canary obligation in the README so the discipline is discoverable in the meantime.
- **Promotion of `ITransportEnvelope.TenantId` to typed.** Wire-shape stability decision in Wave 1 packet 01b. If a future requirement motivates it, becomes a follow-up packet.
- **Consumer-Node wiring (Notify intake adopts `ITenantRateLimitPolicy`; Notify Cloud's Stripe billing emitter; Communications decision-log integration).** Each Node owns its own packet. **Not in this initiative** per the user's framing.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND the Wave 3 exit criteria are met (specifically the Status flip), the entire `active/adr-0026-grid-multi-tenant-primitives/` folder moves to `completed/adr-0026-grid-multi-tenant-primitives/` in a single commit. Partial archival is forbidden. If Pulse (packet 03) is still open at the time the other six close, the folder stays in `active/` until Pulse closes too.

## `gh` CLI Commands — File By Wave

Run from the `HoneyDrunk.Architecture` repo root. Paths are relative.

```bash
PACKETS="generated/issue-packets/active/adr-0026-grid-multi-tenant-primitives"

# --- Wave 1: coordinated five-Node bump (file all five at once; merge Kernel first; downstream PRs merge as green) ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel \
  --title "Grid multi-tenant primitives: typed TenantId, Internal sentinel, ITenantRateLimitPolicy, IBillingEventEmitter, noop defaults" \
  --body-file $PACKETS/01-kernel-multi-tenant-primitives.md \
  --label "feature,tier-3,core,breaking-change,adr-0026,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Data \
  --title "Adapt KernelTenantAccessor to Kernel 0.5.0 typed IOperationContext.TenantId" \
  --body-file $PACKETS/01a-data-tenant-accessor-typed-adoption.md \
  --label "chore,tier-2,core,adr-0026,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Transport \
  --title "Adapt GridContextFactory.InitializeFromEnvelope to Kernel 0.5.0 typed Initialize signature" \
  --body-file $PACKETS/01b-transport-grid-context-factory-typed-adoption.md \
  --label "chore,tier-2,core,adr-0026,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Web.Rest \
  --title "Adapt RequestLoggingScopeMiddleware to Kernel 0.5.0 typed IOperationContext.TenantId" \
  --body-file $PACKETS/01c-web-rest-request-logging-scope-typed-adoption.md \
  --label "chore,tier-2,core,adr-0026,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Pulse \
  --title "Adopt typed TenantId on tenant_id telemetry tag with cardinality discipline doc" \
  --body-file $PACKETS/03-pulse-tenant-id-telemetry-tag.md \
  --label "feature,tier-2,ops,telemetry,adr-0026,wave-1"

# --- Wait for Wave 1 to merge + publish ---

# --- Wave 2: Vault (file after Wave 1 publishes) ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault \
  --title "Per-tenant secret scoping: TenantScopedSecretResolver + docs/Tenancy.md (no ISecretStore change)" \
  --body-file $PACKETS/02-vault-tenant-scoped-secret-resolver.md \
  --label "feature,tier-2,core,docs,adr-0026,wave-2"

# --- Wait for Wave 2 to merge + publish ---

# --- Wave 3: Architecture acceptance (file after Wave 1 hard packets + Vault publish; Pulse may still be in-flight) ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "ADR-0026 acceptance: catalog updates, invariant 37, per-repo boundary refresh, Status flip" \
  --body-file $PACKETS/04-architecture-catalog-invariant-acceptance.md \
  --label "feature,tier-2,docs,governance,adr-0026,wave-3"
```

After filing each wave, wire the blocking relationships per the dependencies declared in each packet's frontmatter:

- Packets 01a, 01b, 01c, 03 → blocked by packet 01 (Kernel) — file Wave 1, then wire these four.
- Packet 02 (Vault) → blocked by packet 01 (Kernel). Soft-blocked by Wave 1 publish (operationally, Vault waits until Wave 1 publishes; this is operator-enforced rather than `addBlockedBy`-encoded).
- Packet 04 (Architecture) → blocked by packets 01, 01a, 01b, 01c, 02. Pulse (03) is soft-blocked per pragmatic reading; can be added if you take the strict reading.

Use `gh api graphql` with `addBlockedBy` for each pair (see `copilot/issue-authoring-rules.md` for the GraphQL mutation shape).

## Notes

- **Foundation primitives, not a feature.** This initiative ships infrastructure that Notify Cloud, Communications, and any future commercial Node will all consume. The wedge is the strong type and the boundary invariant — without those, every commercial Node would invent its own incompatible tenancy layer.
- **Why coordinated Wave 1.** ADR-0026 D9 (revised after refine) explicitly says the typed `IGridContext.TenantId` and `IOperationContext.TenantId` promotion is a minor breaking change with a known blast radius — four downstream Nodes (Data, Transport, Web.Rest, Pulse). Shipping Kernel 0.5.0 alone would create a transient broken-restore window. Coordinated Wave 1 closes that window.
- **Coupling with PDR-0002.** PDR-0002 (Notify Cloud) listed these primitives as Notify-specific in §F; ADR-0026 reframes them as Grid-wide. The cost difference (one upfront design vs. retrofitting later) is the load-bearing rationale.
- **No site-sync packet.** The Studios website auto-imports `catalogs/contracts.json` and `catalogs/grid-health.json` on the next build; no manual site work needed. The new contracts will appear on the Kernel detail page automatically.
- **No new initiative for Notify Cloud.** Notify Cloud's standup is its own ADR (PDR-0002 §Recommended Follow-Up Artifacts); this initiative completes when the seven packets are accepted, not when Notify Cloud ships.
- **Naming rule check.** `TenantRateLimitDecision` and `BillingEvent` are records (no `I`). `ITenantRateLimitPolicy` and `IBillingEventEmitter` are interfaces (kept `I`). `TenantRateLimitOutcome` is an enum (no prefix). Per memory `project_naming_rule_records`.
- **No ADR ID in code / package READMEs.** Per memory `feedback_no_adr_in_docs`. Architecture-knowledge-base docs (constitution, catalogs, ADR index, per-repo boundary docs, `copilot/issue-authoring-rules.md`) are an exception by existing precedent — they reference ADRs by number with brief glosses.
- **Sentinel literal: `00000000000000000000000000`.** Verified at packet authoring with Cysharp Ulid 1.4.1 runtime probe. Equivalent to `Ulid.MinValue`. Round-trips through `ToString()`. Unobtainable from `Ulid.NewUlid()` in practice. Canary-pinned for the lifetime of the type.
