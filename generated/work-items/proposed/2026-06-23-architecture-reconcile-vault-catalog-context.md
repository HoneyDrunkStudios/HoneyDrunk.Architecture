---
title: Reconcile Vault catalog and context drift
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
node: HoneyDrunk.Architecture
wave: 1
tier: tier-1
labels:
  - chore
  - tier-1
  - sector-meta
adrs:
  - ADR-0005
  - ADR-0006
  - ADR-0026
  - ADR-0043
initiative: tactical-node-audit
dependencies: []
source: tactical
generator: node-audit
---

# Reconcile Vault catalog and context drift

## Summary

Update Architecture's Vault metadata so catalogs and repo context reflect the current Vault 0.7.0 package surface, Kernel compatibility, App Configuration/EventGrid packages, and required context files.

## Context

The 2026-06-23 tactical audit for HoneyDrunk.Vault found Architecture drift:

- `repos/HoneyDrunk.Vault/overview.md` still says version `0.5.0`.
- `catalogs/compatibility.json` still says `honeydrunk-vault` current version `0.5.0` and Kernel compatibility `>=0.7.0`.
- The audited Vault repo's packages are `0.7.0`, and the core package references Kernel `0.8.0`.
- `catalogs/relationships.json` omits `HoneyDrunk.Vault.Providers.AppConfiguration` and `HoneyDrunk.Vault.EventGrid` from the Vault package surface.
- `repos/HoneyDrunk.Vault/active-work.md` is missing, leaving the context folder incomplete.

Audit report: `generated/audits/HoneyDrunk.Vault-2026-06-23.md`

## Scope

- Update Vault entries in `repos/HoneyDrunk.Vault/overview.md`.
- Add `repos/HoneyDrunk.Vault/active-work.md` with current known work and audit follow-ups.
- Reconcile `catalogs/compatibility.json` for Vault version and Kernel compatibility.
- Reconcile `catalogs/relationships.json` Vault package exposure to include current packages.
- Reconcile `catalogs/contracts.json` if needed so the current Vault package/contract surface is not understated.
- Keep the change to Architecture metadata only. Do not modify the Vault repository in this packet.

## Acceptance Criteria

- [ ] Architecture's Vault overview records the current audited package version or explicitly explains why the catalog version intentionally differs from package versions.
- [ ] Vault compatibility reflects the current Kernel version consumed by the repo, or explicitly documents the lower-bound compatibility policy.
- [ ] `HoneyDrunk.Vault.Providers.AppConfiguration` and `HoneyDrunk.Vault.EventGrid` are represented in the Vault package surface where Architecture catalogs packages.
- [ ] `repos/HoneyDrunk.Vault/active-work.md` exists and names the active tactical follow-up for App Configuration host-builder compatibility.
- [ ] Boundary wording clarifies that Vault owns the `IConfigProvider` / App Configuration bootstrap seam while application Nodes own their own configuration models and values.
- [ ] No secret values, customer PII, webhook URLs, tokens, or full stack traces are copied into Architecture docs, generated packets, PR body, or comments.
- [ ] Validation includes a diff review plus a targeted search confirming there is no remaining `0.5.0` Vault version claim in current Vault Architecture context unless intentionally retained with an explanation.

## Human Prerequisites

None.

## Dependencies

None.

## Constraints

- Grid invariant 8: Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. Extend that same redaction discipline to generated reports, packets, docs, PR bodies, and comments.
- Grid invariant 98 context-folder requirement excerpt: an accepted Node scaffold includes a context folder at `repos/{NodeName}/` with all five files: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, and `integration-points.md`.
- Grid invariant 108: Every agent-generated packet authored after ADR-0043 acceptance lands in `generated/work-items/proposed/`, not `generated/work-items/active/`. Agents do not self-promote; a human is the only authority for the `proposed/` to `active/` transition.
- Grid invariant 109: Every work item authored after ADR-0043 acceptance carries `source` and `generator` frontmatter fields before it is eligible for filing. For ADR-0043 agent-generated backlog packets, `source` is one of `strategic`, `tactical`, `opportunistic`, or `reactive`; for human-authored packets, `source` may be `human`. `generator` is the agent name that produced it or `human` for human-authored packets.
- Vault boundary: Vault owns unified secret access via `ISecretStore`, multi-provider support with automatic fallback, in-memory caching with configurable TTL, resilience policies, provider-slot pattern (`ISecretProvider`), secure telemetry that never logs secret values, and `SecretIdentifier`, `SecretValue`, `VaultResult<T>` models.
- Vault boundary: Vault does not own application-level configuration. Vault provides `IConfigProvider`; apps define their configuration models.
- ADR-0005 bootstrap rule: App Configuration is the shared non-secret config store, label-partitioned per Node, with `AZURE_APPCONFIG_ENDPOINT` supplied via environment configuration at deploy time.
- ADR-0006 rotation rule: Vault cache invalidation is event-driven through Event Grid on `SecretNewVersionCreated`, with TTL as fallback; applications must resolve latest through `ISecretStore` and must not pin secret versions.
- ADR-0026 tenant-scoped secret rule: tenant-owned secrets use `tenant-{tenantId}-{secretName}` through `TenantScopedSecretResolver`; `ISecretStore` is not changed for tenancy.

## Agent Handoff

**Objective:** Bring Architecture's Vault catalog/context metadata back in line with the current Vault package surface and required context-folder shape.

**Target:** HoneyDrunk.Architecture, branch from `main`

**Context:**
- Goal: ADR-0043 tactical audit follow-up
- Feature: Vault metadata reconciliation
- ADRs: ADR-0005, ADR-0006, ADR-0026, ADR-0043

**Acceptance Criteria:**
- [ ] Catalog/context edits are limited to Vault metadata and do not create unrelated Architecture churn.
- [ ] `active-work.md` is present for Vault.
- [ ] The result passes a manual code-review pass before PR publish.

**Dependencies:**
- None.

**Constraints:**
- Do not modify `generated/work-items/active/` or move any packets.
- Do not create GitHub issues or mutate The Hive board.
- Do not touch the audited Vault repo from this Architecture metadata packet.

**Key Files:**
- `repos/HoneyDrunk.Vault/overview.md`
- `repos/HoneyDrunk.Vault/boundaries.md`
- `repos/HoneyDrunk.Vault/active-work.md`
- `catalogs/compatibility.json`
- `catalogs/relationships.json`
- `catalogs/contracts.json`

**Contracts:**
- Architecture metadata only; no code contract changes.
