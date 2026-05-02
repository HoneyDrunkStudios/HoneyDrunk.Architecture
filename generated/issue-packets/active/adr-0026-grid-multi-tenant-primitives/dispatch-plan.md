# Dispatch Plan: ADR-0026 Grid Multi-Tenant Primitives

**Date:** 2026-05-02
**Trigger:** ADR-0026 (Grid Multi-Tenant Primitives) Proposed — settles `TenantId` promotion, `Internal` sentinel, `ITenantRateLimitPolicy`, `IBillingEventEmitter`, per-tenant Vault scoping pattern, `tenant_id` Pulse telemetry discipline, and the multi-tenant boundary invariant.
**Type:** Multi-repo
**Sector:** Core (Kernel, Vault) · Ops (Pulse) · Meta (Architecture)
**Site sync required:** No (no public-facing surface change; site catalogs auto-import from `catalogs/contracts.json` on next Studios build).
**Rollback plan:**
- Packet 01 (Kernel) is a minor version bump with a small breaking change on `IGridContext.TenantId`. Rollback: revert the PR; consumers stay on Kernel 0.4.x with `string?` TenantId. The audit confirmed zero non-Kernel callsites consume the property today, so the blast radius is empty.
- Packet 02 (Vault) is purely additive (new doc + new resolver + version bump). Rollback: revert the PR; the resolver is removed but `ISecretStore` is unchanged.
- Packet 03 (Pulse) is a typed-adoption change. Rollback: revert the PR; Pulse stays on `0.1.0` with the `string?` TenantId pattern. No telemetry consumers break.
- Packet 04 (Architecture) is docs only. Rollback: revert the PR; ADR-0026 returns to Proposed, invariant 37 is removed, catalog regresses. No runtime impact.

## Summary

ADR-0026 makes multi-tenancy a Grid-wide primitive concern rather than a Notify Cloud-specific code path. The four-packet rollout:

1. **Kernel (packet 01).** Promotes `IGridContext.TenantId` from `string?` to non-nullable `TenantId`. Adds `TenantId.Internal` sentinel + `IsInternal` predicate (canary-pinned). Adds the `Tenancy` namespace to `HoneyDrunk.Kernel.Abstractions` with `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `TenantRateLimitOutcome`, `IBillingEventEmitter`, `BillingEvent`. Ships `NoopTenantRateLimitPolicy` and `NoopBillingEventEmitter` defaults in `HoneyDrunk.Kernel`. Updates `GridContextMiddleware`, `MessagingContextMapper`, `JobContextMapper`, `GridContextSerializer` to apply the `Internal` default at Grid entry. Coordinated `0.4.x → 0.5.0` minor bump on Kernel + Kernel.Abstractions per Invariant 27. **One consolidated Kernel packet** (the ADR's three sub-bullets ship together — separate PRs would force three solution-version bumps within days, violating the spirit of Invariant 27 and creating partial-state windows for consumers).

2. **Vault (packet 02).** Adds `HoneyDrunk.Vault/docs/Tenancy.md` documenting the `tenant-{tenantId}-{secretName}` convention. Adds `TenantScopedSecretResolver` to the Vault runtime as a thin composition over `ISecretStore`. **No contract change to `ISecretStore`.** Coordinated `0.2.0 → 0.3.0` bump.

3. **Pulse (packet 03).** Adopts the typed `TenantId` in `ActivityEnricher` and the Collector enrichers. Replaces `string.IsNullOrEmpty` checks with `IsInternal` short-circuit at the source. Adds a cardinality discipline doc anchored on PDR-0002 §K (paying customers measured in tens at v1; alarm at 200 distinct tenant IDs / 24h). Coordinated `0.1.0 → 0.2.0` bump.

4. **Architecture (packet 04).** Appends multi-tenant boundary invariant (37) to `constitution/invariants.md`. Adds catalog entries for the four new Kernel surfaces in `catalogs/contracts.json`. Updates `repos/HoneyDrunk.Kernel/boundaries.md` + `invariants.md`. Updates `repos/HoneyDrunk.Vault/boundaries.md`. Flips ADR-0026 Status from Proposed to Accepted. Records initiative completion in `active-initiatives.md`.

The two changes from PDR-0002 §F that are NOT primitive-shaped (per-tenant API keys, multi-tenant Web.Rest auth path) are explicitly out of this initiative — they live in the Notify Cloud standup ADR + an Auth-side ADR and are scoped separately.

## Execution Model

Sequenced by D9 — strict ordering between waves. Wave 1 must publish before Wave 2 starts; both Kernel + Vault must publish before Wave 3.

Within Wave 2, Vault and Pulse run in parallel — they have no inter-dependency. Both depend on Wave 1.

Manual dispatch on Codex Cloud expected — packet 01 is a Tier 3 cross-repo change (breaking change on `IGridContext.TenantId`) that warrants human PR review before downstream packets begin. Filing is gated: file Wave 1 first, wait for merge + publish, then file Wave 2.

### Wave 1 — Kernel foundation (file first; all downstream waves block on this)

- [ ] `HoneyDrunk.Kernel`: Grid multi-tenant primitives — typed `TenantId`, `Internal` sentinel, four contracts, noop defaults, mapper/middleware/serializer adoption, coordinated 0.5.0 bump — [`01-kernel-multi-tenant-primitives.md`](01-kernel-multi-tenant-primitives.md)

**Wave 1 exit criteria:**
- Kernel packet PR merged to `main`.
- `HoneyDrunk.Kernel.Abstractions` 0.5.0 and `HoneyDrunk.Kernel` 0.5.0 published to the Grid's NuGet feed (verify with `dotnet list package` against a sample consumer or by querying the feed directly).
- Canary tests green (contract-shape canary on the four new surfaces; `TenantId.Internal` literal pinning canary; noop default behavior canaries).
- All downstream non-Kernel consumers verified non-broken (`rg "gridContext\.TenantId|\.TenantId\s*[?]"` across the workspace).

### Wave 2 — Vault + Pulse adoption (parallel, file after Wave 1 merges + publishes)

- [ ] `HoneyDrunk.Vault`: Per-tenant secret scoping pattern + `TenantScopedSecretResolver` + `docs/Tenancy.md` + 0.3.0 bump — [`02-vault-tenant-scoped-secret-resolver.md`](02-vault-tenant-scoped-secret-resolver.md)
- [ ] `HoneyDrunk.Pulse`: Typed `TenantId` adoption in enrichers + cardinality discipline doc + 0.2.0 bump — [`03-pulse-tenant-id-telemetry-tag.md`](03-pulse-tenant-id-telemetry-tag.md)

**Wave 2 exit criteria:**
- Both packets PR merged to `main`.
- `HoneyDrunk.Vault` 0.3.0 published.
- `HoneyDrunk.Pulse` package(s) 0.2.0 published.
- Test suites green on both repos.
- Vault: `git diff HoneyDrunk.Vault/Abstractions/` is empty (no `ISecretStore` change).
- Pulse: tag key `tenant_id` preserved; string-overload of `EnrichWithGridContext` signature unchanged.

### Wave 3 — Architecture acceptance (file after Wave 1 + Vault from Wave 2 publish; Pulse can still be in-flight per pragmatic reading)

- [ ] `HoneyDrunk.Architecture`: Catalog updates + invariant 37 + per-repo boundary refresh + ADR-0026 Status flip to Accepted — [`04-architecture-catalog-invariant-acceptance.md`](04-architecture-catalog-invariant-acceptance.md)

**Wave 3 exit criteria:**
- Wave 3 PR merged to `main`.
- ADR-0026 status header reads `Accepted`.
- `constitution/invariants.md` includes invariant 37 (or whatever number was assigned at execution — verify before merge).
- `catalogs/contracts.json` includes the five new Kernel-Tenancy entries and validates as well-formed JSON (`jq` check).
- `initiatives/active-initiatives.md` has an ADR-0026 entry showing Kernel + Vault + Architecture rows checked, Pulse row checked or noted as open.

**Acceptance reading (pragmatic vs strict):** Default behavior is **pragmatic** — flip Status to Accepted when Kernel + Vault land (the primitives themselves are settled and shipped); Pulse is a downstream consumer-side adoption that does not affect the primitive contracts. ADR-0026 D9 explicitly says "Step 3 is consumer-Node work that proceeds under its own ADRs and packets" and Pulse adoption fits that frame. The strict reading (wait for Pulse to merge before flipping) is also defensible — choose at PR review on packet 04. The packet defaults to pragmatic and tracks Pulse as an open checkbox in `active-initiatives.md` if it hasn't merged.

## Open Bikeshed (Human Decision Required Before Wave 1 Merge)

Per ADR-0026 Open Questions §3 and memory `project_human_only_convention`, one decision in Wave 1 needs human confirmation:

- **`TenantId.Internal` ULID literal value.** The agent will write a parseable ULID into the canary (proposed: `00000000000000000000000001`, with a fallback if the constructor rejects all-zero-prefix ULIDs). The human (oleg@honeydrunkstudios.com) confirms or replaces the literal at PR review on packet 01. Once merged, the canary pins it for the lifetime of the type — changing it later breaks every consumer's `IsInternal` check. **This is a sub-decision the agent brings back, not a `human-only` packet.** The code work itself can be delegated; only the literal value choice is the human bikeshed.

The four packets all default to `Actor=Agent`. None receive the `human-only` label.

## Out of Scope (Explicitly Deferred to Other ADRs / Packets)

Per ADR-0026 D10 and the user's framing:

- **Per-tenant API key issuance, validation, storage.** Notify Cloud + Auth concern. Separate "API key authentication pattern ADR" (PDR-0002 §Recommended Follow-Up Artifacts).
- **Multi-tenant Web.Rest auth path.** Same — Auth-and-Notify-Cloud concern.
- **Rate-limit storage backend (Redis / Azure Storage Tables / etc.).** Notify Cloud picks during its standup ADR.
- **Billing-event queue topology, Stripe webhook bridge.** `HoneyDrunk.Notify.Cloud.Billing.Stripe` packet — separate ADR.
- **Project-scoped tenancy (`ProjectId` promotion).** Future ADR; Notify Cloud v1 is per-tenant, not per-project.
- **Tenant abuse detection, fraud signals, automatic pause.** Operations concerns — surfaced via Pulse, not primitives.
- **Multi-region tenancy.** Notify Cloud v1 is single-region.
- **Static analyzer that flags `ITenantRateLimitPolicy` references inside `Routing/`, `Worker/`, or `Providers/` folders.** Future `HoneyDrunk.Standards` packet (ADR-0026 Open Questions §2). Not gating.
- **Test fixtures for tenancy (`HoneyDrunk.Kernel.Testing` companion).** Future packet — defer until the first consumer asks for it.
- **Consumer-Node wiring (Notify intake adopts `ITenantRateLimitPolicy`; Notify Cloud's Stripe billing emitter; Communications decision-log integration).** Each Node owns its own packet. **Not in this initiative** per the user's framing.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND the Wave 3 exit criteria are met (specifically the Status flip), the entire `active/adr-0026-grid-multi-tenant-primitives/` folder moves to `completed/adr-0026-grid-multi-tenant-primitives/` in a single commit. Partial archival is forbidden. If Pulse (packet 03) is still open at the time the other three close, the folder stays in `active/` until Pulse closes too.

## `gh` CLI Commands — File By Wave

Run from the `HoneyDrunk.Architecture` repo root. Paths are relative.

```bash
PACKETS="generated/issue-packets/active/adr-0026-grid-multi-tenant-primitives"

# --- Wave 1: Kernel foundation (file first; wait for merge + publish before Wave 2) ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel \
  --title "Grid multi-tenant primitives: typed TenantId, Internal sentinel, ITenantRateLimitPolicy, IBillingEventEmitter, noop defaults" \
  --body-file $PACKETS/01-kernel-multi-tenant-primitives.md \
  --label "feature,tier-3,core,breaking-change,adr-0026,wave-1"

# --- Wave 2: Vault + Pulse (file after Wave 1 merges AND Kernel 0.5.0 publishes) ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault \
  --title "Per-tenant secret scoping: TenantScopedSecretResolver + docs/Tenancy.md (no ISecretStore change)" \
  --body-file $PACKETS/02-vault-tenant-scoped-secret-resolver.md \
  --label "feature,tier-2,core,docs,adr-0026,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Pulse \
  --title "Adopt typed TenantId on tenant_id telemetry tag with cardinality discipline doc" \
  --body-file $PACKETS/03-pulse-tenant-id-telemetry-tag.md \
  --label "feature,tier-2,ops,telemetry,adr-0026,wave-2"

# --- Wave 3: Architecture acceptance (file after Wave 1 + Vault from Wave 2 publish; Pulse may still be in-flight) ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "ADR-0026 acceptance: catalog updates, invariant 37, per-repo boundary refresh, Status flip" \
  --body-file $PACKETS/04-architecture-catalog-invariant-acceptance.md \
  --label "feature,tier-2,docs,governance,adr-0026,wave-3"
```

After filing each wave, wire the blocking relationships per the dependencies declared in each packet's frontmatter:

- Packet 02 (Vault) → blocked by packet 01 (Kernel)
- Packet 03 (Pulse) → blocked by packet 01 (Kernel)
- Packet 04 (Architecture) → blocked by packet 01 (Kernel) AND packet 02 (Vault) — pragmatic reading; add packet 03 too if you take the strict reading

Use `gh api graphql` with `addBlockedBy` for each pair (see `copilot/issue-authoring-rules.md` for the GraphQL mutation shape).

## Notes

- **Foundation primitives, not a feature.** This initiative ships infrastructure that Notify Cloud, Communications, and any future commercial Node will all consume. The wedge is the strong type and the boundary invariant — without those, every commercial Node would invent its own incompatible tenancy layer.
- **Coupling with PDR-0002.** PDR-0002 (Notify Cloud) listed these primitives as Notify-specific in §F; ADR-0026 reframes them as Grid-wide. The cost difference (one upfront design vs. retrofitting later) is the load-bearing rationale.
- **No site-sync packet.** The Studios website auto-imports `catalogs/contracts.json` on the next build; no manual site work needed. The new contracts will appear on the Kernel detail page automatically.
- **No new initiative for Notify Cloud.** Notify Cloud's standup is its own ADR (PDR-0002 §Recommended Follow-Up Artifacts); this initiative completes when the four primitives are accepted, not when Notify Cloud ships.
- **Naming rule check.** `TenantRateLimitDecision` and `BillingEvent` are records (no `I`). `ITenantRateLimitPolicy` and `IBillingEventEmitter` are interfaces (kept `I`). `TenantRateLimitOutcome` is an enum (no prefix). Per memory `project_naming_rule_records`.
- **No ADR ID in code / package READMEs.** Per memory `feedback_no_adr_in_docs`. Architecture-knowledge-base docs (constitution, catalogs, ADR index, per-repo boundary docs) are an exception by existing precedent — they reference ADRs by number with brief glosses.
