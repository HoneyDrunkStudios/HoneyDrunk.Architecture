# Release Tracking

Centralized view of what shipped across the Grid.

**Last Updated:** 2026-04-16

---

## Q2 2026

> **Human review pending:** Four release drift entries below (Vault, Auth, Web.Rest, Data 0.4.0, last_release: 2026-04-05 per grid-health.json). Awaiting CHANGELOG confirmation and release notes. Note: Vault#12 ("Release Vault v0.3.0") still open — verify whether 0.3.0 or 0.4.0 is the actual published version before finalizing.

### Pending Verification

#### Vault 0.4.0

- **Signal:** Live
- **Shipped:** Q2 2026 (2026-04-05 per grid-health.json)
- **Highlights:**
  - Highlights pending — check HoneyDrunk.Vault CHANGELOG and confirm tag exists before publishing
- **Breaking Changes:** Unknown — review CHANGELOG

#### Auth 0.4.0

- **Signal:** Live
- **Shipped:** Q2 2026 (2026-04-05 per grid-health.json)
- **Highlights:**
  - Highlights pending — check HoneyDrunk.Auth CHANGELOG and confirm tag exists before publishing
- **Breaking Changes:** Unknown — review CHANGELOG

#### Web.Rest 0.4.0

- **Signal:** Live
- **Shipped:** Q2 2026 (2026-04-05 per grid-health.json)
- **Highlights:**
  - Highlights pending — check HoneyDrunk.Web.Rest CHANGELOG and confirm tag exists before publishing
- **Breaking Changes:** Unknown — review CHANGELOG

#### Data 0.4.0

- **Signal:** Live
- **Shipped:** Q2 2026 (2026-04-05 per grid-health.json)
- **Highlights:**
  - Highlights pending — check HoneyDrunk.Data CHANGELOG and confirm tag exists before publishing
- **Breaking Changes:** Unknown — review CHANGELOG

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
| Pulse | 0.1.0 GA | Q2 2026 | Production hardening, Grafana dashboards |
| Notify | 0.1.0 GA | Q2 2026 | Azure Functions deployment finalization |
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
