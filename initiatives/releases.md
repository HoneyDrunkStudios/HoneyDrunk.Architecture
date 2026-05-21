# Release Tracking

Centralized view of what shipped across the Grid.

**Last Updated:** 2026-05-21

---

## Q2 2026

> **Human review pending:** Vault.Rotation still has no published package/tag by decision; keep it out of release history until Oleg asks for an actual release.

### Pending Verification

#### Vault.Rotation initial release

- **Signal:** Seed
- **Shipped:** Not released
- **Highlights:**
  - Repo scaffold and Function app implementation are in place.
  - Kernel timer-context alignment landed, but no package/tag was needed for that pass.
- **Breaking Changes:** N/A (not released)

### Kernel 0.7.0

- **Signal:** Live
- **Shipped:** 2026-05-17
- **Highlights:**
  - Canonical `WellKnownNodes` identifiers for active Grid Nodes
  - Current `TenantId` / Grid / Operation context contracts consumed by downstream Core packages
  - Baseline for the Kernel adoption alignment wave
- **Breaking Changes:** Yes — downstream packages aligned to the current Kernel context/identity contract

### Transport 0.6.0

- **Signal:** Live
- **Shipped:** 2026-05-18
- **Highlights:**
  - Removed full Kernel runtime dependency; Transport consumes Kernel abstractions for context propagation
  - Fail-fast envelope/Grid context validation preserved
  - Repository changelog finalized after tag publication
- **Breaking Changes:** Yes — Kernel dependency shape and package baseline changed during pre-1.0 alignment

### Vault 0.5.0

- **Signal:** Live
- **Shipped:** 2026-05-18
- **Highlights:**
  - Aligned Vault to Kernel 0.7.0 package baseline
  - Consolidated provider helpers
  - Preserved cooperative cancellation behavior through facades
- **Breaking Changes:** Yes — pre-1.0 Kernel baseline alignment

### Data 0.6.0

- **Signal:** Live
- **Shipped:** 2026-05-18
- **Highlights:**
  - Aligned Data to Kernel 0.7.0 / Transport 0.6.0
  - Outbox enrichment now requires live operation context or explicit non-empty CorrelationId/TenantId
  - Consolidated EF/SQL test and registration helpers
- **Breaking Changes:** Yes — stricter outbox context requirement

### Auth 0.5.0

- **Signal:** Live
- **Shipped:** 2026-05-21
- **Highlights:**
  - Wired Auth as the first downstream `IAuditLog` emitter via `HoneyDrunk.Audit.Abstractions` 0.1.0
  - Emits fail-soft token validation and authorization decision audit records
  - Preserves token/claims privacy by avoiding raw bearer tokens and subject-claim payload copies in audit metadata
- **Breaking Changes:** No — additive audit emission with fail-soft behavior

### Audit 0.1.0

- **Signal:** Live
- **Shipped:** 2026-05-21
- **Highlights:**
  - Initial `HoneyDrunk.Audit.Abstractions` and `HoneyDrunk.Audit.Data` packages released
  - Append-only-by-interface durable audit records with activity/security/system/data-change categories
  - Data-backed store, query surface, in-memory fixtures, and contract-shape canaries shipped
- **Breaking Changes:** N/A (initial release)

### Auth 0.4.0

- **Signal:** Live
- **Shipped:** 2026-05-18
- **Highlights:**
  - Aligned Auth to current Kernel packages
  - Preserved validation-only boundary; no token issuance added
  - Updated integration docs for Kernel/Vault boundary shape
- **Breaking Changes:** Yes — pre-1.0 Kernel baseline alignment

### Web.Rest 0.5.0

- **Signal:** Live
- **Shipped:** 2026-05-18
- **Highlights:**
  - Requires Kernel request context at DI registration and live execution
  - Treats Kernel `IOperationContext.CorrelationId` as authoritative
  - Consolidated API result factories without changing serialized response contracts
- **Breaking Changes:** Yes — stricter Kernel context requirement

### Notify 0.3.0

- **Signal:** Live
- **Shipped:** 2026-05-18
- **Highlights:**
  - Uses Kernel canonical Notify identity fallback while preserving deploy-time overrides
  - Queue credential resolution moved behind Vault-backed `ISecretStore`
  - Template/provider/queue registration helpers consolidated
- **Breaking Changes:** Yes — pre-1.0 Kernel/secret-boundary alignment

### Pulse 0.3.0

- **Signal:** Live
- **Shipped:** 2026-05-18
- **Highlights:**
  - Uses Kernel canonical Pulse identity fallback while preserving `HONEYDRUNK_NODE_ID`
  - Loki/Mimir/Tempo share internal HTTP OTLP export/auth/retry helpers
  - NuGet packages and GitHub Release published; container image publication blocked separately by upstream Ubuntu `sed` CVE-2026-5958
- **Breaking Changes:** Yes — pre-1.0 Kernel/Transport baseline alignment

### Communications 0.2.0

- **Signal:** Live
- **Shipped:** 2026-05-18
- **Highlights:**
  - Removed full `HoneyDrunk.Kernel` runtime dependency from Communications runtime
  - Runtime consumes Kernel abstractions only and `HoneyDrunk.Notify.Abstractions` 0.3.0
  - Internal tenant handling aligned to Kernel `TenantId.Internal` / `TenantId.IsInternal`
- **Breaking Changes:** Yes — pre-1.0 dependency-shape alignment

### Communications 0.1.0

- **Signal:** Live
- **Shipped:** 2026-05-05
- **Highlights:**
  - Initial `HoneyDrunk.Communications.Abstractions` and runtime packages released
  - Public orchestration contracts for intents, recipient resolution, preferences, cadence, decisions, and decision logs
  - Welcome-email runtime slice delegates approved delivery to Notify
  - In-memory preference/cadence/decision-log implementations for bring-up
- **Breaking Changes:** N/A (initial release)

### Notify 0.2.0

- **Signal:** Live
- **Shipped:** 2026-05-05
- **Highlights:**
  - ADR-0019 boundary refactor: Notify now owns intake/delivery mechanics only
  - Removed Notify-owned policy evaluation surface and default policy pipeline
  - Renamed runtime `Orchestration/` area to `Intake/`
  - Azure Functions deploy workflow completed after release
- **Breaking Changes:** Yes — removed pre-1.0 policy evaluation types; no downstream users yet

---

## Q1 2026

### Kernel 0.4.0

- **Signal:** Live
- **Shipped:** Q1 2026
- **Highlights:**
  - Three-tier context model (Grid → Node → Operation)
  - Static context mappers (HTTP, Messaging, Job)
  - DI guard for registration order validation
  - Removed BCL wrappers (IClock, IIdGenerator, ILogSink)
- **Breaking Changes:** Yes — removed IClock, IIdGenerator, ILogSink

### Transport 0.4.0

- **Signal:** Live
- **Shipped:** Q1 2026
- **Highlights:**
  - Kernel 0.4.0 integration (GridContext propagation)
  - Fail-fast envelope validation
  - EnvelopeFactory with TimeProvider and CorrelationId
  - Thread-safe disposal pattern
- **Breaking Changes:** Yes — envelope creation via factory only

### Vault 0.2.0

- **Signal:** Live
- **Shipped:** Q1 2026
- **Highlights:**
  - Full provider implementations (Azure Key Vault, AWS, File, InMemory)
  - SecretIdentifier + VaultResult pattern
  - Grid-integrated registration flow
  - Canary test coverage
- **Breaking Changes:** No

### Auth 0.2.0

- **Signal:** Live
- **Shipped:** Q1 2026
- **Highlights:**
  - Vault-backed signing key retrieval
  - Policy evaluator
  - Startup validation hooks
- **Breaking Changes:** No

### Web.Rest 0.2.0

- **Signal:** Live
- **Shipped:** Q1 2026
- **Highlights:**
  - Exception mapping middleware
  - Correlation mismatch warnings
  - Optional Transport integration for outbox
- **Breaking Changes:** No

### Data 0.3.0

- **Signal:** Live
- **Shipped:** Q1 2026
- **Highlights:**
  - Architecture overhaul
  - Transport outbox store abstraction
  - Canary coverage expansion
- **Breaking Changes:** Yes — architecture restructure

### Pulse 0.1.0

- **Signal:** Seed
- **Shipped:** Q1 2026 (wrapping up)
- **Highlights:**
  - Multi-backend sinks
  - Pulse.Collector with Kernel integration
  - Contracts package for cross-node telemetry
- **Breaking Changes:** N/A (initial release)

### Notify 0.1.0

- **Signal:** Live
- **Shipped:** Q1 2026 (wrapping up)
- **Highlights:**
  - Email and SMS providers
  - Queue backend support
  - Azure Functions deployment target
- **Breaking Changes:** N/A (initial release)

---

## Upcoming

See [roadmap.md](roadmap.md) for planned work.

| Node | Next Version | Target | Key Goal |
|------|-------------|--------|----------|
| Pulse | production deploy follow-up | Q2 2026 | Resolve container scan/image publication follow-up, production hardening, Grafana dashboards |
| HoneyDrunk.Communications | 0.3.0 | Q2 2026 | Durable stores/testing package if needed by first consumers |
| Notify | deployment follow-up | Q2 2026 | Provider hardening, production smoke coverage, Functions/Worker Azure bring-up |
| Agent Kit | 0.1.0 | Q2 2026 | Agent execution runtime, tool abstraction |
| Orchestrator | 0.1.0 | Q2 2026 | Workflow orchestration, multi-step pipelines |
| HoneyHub | 0.1.0 | Q2–Q3 2026 | Project orchestration, creator dashboard |

---

## How to Update This File

When shipping a release:
1. Add a new section under the correct quarter heading.
2. Include: Signal, Ship date, Highlights (bullet list), Breaking Changes (yes/no + brief summary).
3. Update the Upcoming table if the release was listed there.
4. Update `catalogs/compatibility.json` if version requirements changed.
