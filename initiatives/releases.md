# Release Tracking

Centralized view of what shipped across the Grid.

**Last Updated:** 2026-04-30

---

## Q2 2026

### Vault 0.4.0

- **Signal:** Live
- **Shipped:** Q2 2026 (2026-04-05 per grid-health.json, tagged 2026-04-25 via Vault#12)
- **Highlights:**
  - Env-driven bootstrap via `AddVault()` + `AddAppConfiguration()` extensions
  - Event-driven SecretCache invalidation via Azure Event Grid
  - Full provider implementations (Azure Key Vault, AWS, File, InMemory)
- **Breaking Changes:** Unknown — review CHANGELOG for migration details

### Auth 0.4.0

- **Signal:** Live
- **Shipped:** Q2 2026 (2026-04-05 per grid-health.json, tagged 2026-04-25)
- **Highlights:**
  - Vault-backed signing key retrieval
  - Startup validation and policy evaluation improvements
  - Kernel 0.4.0 contract alignment
- **Breaking Changes:** Unknown — review CHANGELOG

### Web.Rest 0.4.0

- **Signal:** Live
- **Shipped:** Q2 2026 (2026-04-05 per grid-health.json, tagged 2026-04-25)
- **Highlights:**
  - Exception mapping middleware refinements
  - Correlation mismatch detection improvements
  - Kernel 0.4.0 contract alignment
- **Breaking Changes:** Unknown — review CHANGELOG

### Data 0.4.0

- **Signal:** Live
- **Shipped:** Q2 2026 (2026-04-05 per grid-health.json, tagged 2026-04-25)
- **Highlights:**
  - Architecture overhaul with Transport outbox store abstraction
  - Tenant-aware data access patterns finalized
  - Canary test coverage expansion
- **Breaking Changes:** Yes — architecture restructure. Review CHANGELOG for migration path.

### Vault.Rotation 0.1.0

- **Signal:** Seed
- **Shipped:** Q2 2026 (2026-04-25, repo scaffolded 2026-04-11, scaffold completed 2026-04-25 via Vault.Rotation#3, released 2026-04-25 via Vault.Rotation#4)
- **Highlights:**
  - Baseline Azure Function App scaffold with Kernel integration
  - Vault bootstrap and managed identity setup
  - ADR-0006 Tier-2 operational structure in place
- **Breaking Changes:** N/A (initial release)

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
