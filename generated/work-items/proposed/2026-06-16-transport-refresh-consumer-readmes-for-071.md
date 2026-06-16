---
title: Refresh Transport consumer READMEs for 0.7.1
target_repo: HoneyDrunkStudios/HoneyDrunk.Transport
node: HoneyDrunk.Transport
type: chore
tier: tier-1
sector: Core
wave: standalone
initiative: tactical-node-audit
dependencies: []
labels: ["chore", "tier-1", "sector-core"]
adrs: ["ADR-0043"]
source: tactical
generator: node-audit
---

## Summary

Refresh Transport's root and package READMEs so consumer-facing setup and feature-status guidance matches the current `0.7.1` package set.

## Context

The ADR-0043 tactical audit report at `generated/audits/HoneyDrunk.Transport-2026-06-16.md` found that Transport's root README still frames feature status as `v0.1.0`, while package README XML snippets pin `Version="0.4.0"`. The audited repo has all shipped Transport package projects set to `<Version>0.7.1</Version>`.

Transport is consumed by Web.Rest, Data, NovOutbox, and planned Flow work. Stale README guidance can send consumers to older packages or outdated setup assumptions.

## Scope

- `README.md`
- `HoneyDrunk.Transport/HoneyDrunk.Transport/README.md`
- `HoneyDrunk.Transport/HoneyDrunk.Transport.AzureServiceBus/README.md`
- `HoneyDrunk.Transport/HoneyDrunk.Transport.StorageQueue/README.md`
- `HoneyDrunk.Transport/HoneyDrunk.Transport.InMemory/README.md`
- `HoneyDrunk.Transport/CHANGELOG.md`, only if adding missing release link references for existing `0.6.0`, `0.7.0`, or `0.7.1` headings

Do not change code, package versions, workflows, or generated files.

## Acceptance Criteria

- [ ] Root README no longer presents current status as `v0.1.0` or lists `What's New in v0.1.0` as if it were the current release.
- [ ] Package README install snippets no longer pin stale `Version="0.4.0"` references; they either use `0.7.1` or omit explicit versions consistently with repo documentation style.
- [ ] The READMEs accurately state that Transport consumes Kernel.Abstractions and that applications/host demo composition may register Kernel runtime.
- [ ] Provider READMEs keep the Service Bus vs Storage Queue tradeoffs clear and do not claim broker features Transport does not implement.
- [ ] If release links are touched, repo-level changelog references for existing `0.6.0`, `0.7.0`, and `0.7.1` headings are added without rewriting release history.
- [ ] No package version bump is performed for this docs-only change.

## Human Prerequisites

None.

## Dependencies

None.

## NuGet Dependencies

No NuGet dependency changes.

## Constraints

- Semantic versioning with CHANGELOG and README. Repo-level `CHANGELOG.md`, next to the `.slnx` file, is mandatory. Every repo must have one. It covers the full release holistically. Every version that ships must have an entry here. This is the source for auto-generated release notes.
- Every package directory must also contain a `README.md` describing the package purpose, installation, and public API surface. New projects must have both files from the first commit.
- Transport owns message publishing and consumption abstractions, the middleware pipeline, immutable transport envelopes with correlation/causation tracking, transactional outbox abstractions, transport-specific health contributors, and provider implementations for Azure Service Bus, Storage Queue, and InMemory.
- Transport does not own message serialization format, business logic, database outbox storage, the Kernel context model, REST/HTTP concerns, or queue-based notification management.
- Transport depends only on Kernel.Abstractions, not full Kernel.
- Envelopes are immutable. Use `WithHeaders()` / `WithGridContext()` for modified copies.
- Always use EnvelopeFactory to create envelopes. Never construct `TransportEnvelope` directly.
- Middleware order matters. GridContextPropagation -> Telemetry -> Logging -> Handler.
- Grid context fields are always mapped. NodeId, StudioId, Environment must be propagated to broker metadata.

## Agent Handoff

**Objective:** Refresh Transport consumer documentation for the current `0.7.1` package state.
**Target:** HoneyDrunk.Transport, branch from `main`
**Context:**
- Goal: ADR-0043 tactical node audit follow-up
- Feature: Transport README freshness
- ADRs: ADR-0043

**Acceptance Criteria:**
- [ ] README version/status language matches the current `0.7.1` package state.
- [ ] Installation snippets do not direct consumers to stale `0.4.0` packages.
- [ ] Docs remain scoped to Transport behavior and do not move Data, Kernel, Web.Rest, or Notify responsibilities into Transport.
- [ ] No code, package version, or workflow changes are made.

**Dependencies:**
- None.

**Constraints:**
- Keep this packet docs-only.
- Do not change package versions.
- Do not edit Architecture repo files from the Transport execution PR.

**Key Files:**
- `README.md`
- `HoneyDrunk.Transport/HoneyDrunk.Transport/README.md`
- `HoneyDrunk.Transport/HoneyDrunk.Transport.AzureServiceBus/README.md`
- `HoneyDrunk.Transport/HoneyDrunk.Transport.StorageQueue/README.md`
- `HoneyDrunk.Transport/HoneyDrunk.Transport.InMemory/README.md`
- `HoneyDrunk.Transport/CHANGELOG.md`

**Contracts:**
- None.
