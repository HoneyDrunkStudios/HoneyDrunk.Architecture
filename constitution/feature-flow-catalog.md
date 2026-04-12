# Feature Flow Catalog

Named cross-repo flows that are too important to leave implicit. Each flow shows how a capability travels across multiple Nodes — which contracts cross each boundary and what order repos must be touched. Use this before generating cross-repo issue packets.

Supplement this with `catalogs/relationships.json` for the full dependency graph and `catalogs/contracts.json` for the specific interfaces at each boundary.

---

## Flow 1: Authenticated HTTP Request

**Repos touched:** Kernel → Transport → Auth → Web.Rest  
**Trigger:** An external HTTP client sends a request to any Grid-backed API.

```
HTTP Request (external)
    │
    ▼
[Web.Rest] — reads GridContext, maps correlation IDs from headers
    │ IOperationContextAccessor, CorrelationId
    ▼
[Auth] — validates JWT Bearer token
    │ IAuthenticatedIdentityAccessor, IAuthorizationPolicy
    │ (Vault → ISecretStore → signing key resolution happens inside Auth)
    ▼
[Kernel] — GridContext populated: CorrelationId, TenantId, identity claims
    │ IGridContext, INodeContext
    ▼
[Application handler] — executes business logic with full Grid context
    │
    ▼
[Web.Rest] — wraps response in ApiResult envelope, maps exceptions to ApiErrorResponse
    │
    ▼
HTTP Response → external client
```

**Cross-repo ordering for changes:**
1. Kernel.Abstractions (if context contracts change)
2. Vault (if secret retrieval changes)
3. Auth (if token validation changes)
4. Web.Rest (if envelope or middleware changes)

**Canary:** Web.Rest.Canary must validate Auth integration; Auth.Canary must validate Vault integration.

---

## Flow 2: Notification Dispatch

**Repos touched:** Kernel → Transport → Notify  
**Trigger:** Any Node needs to send a notification (email, SMS) to a user or system.

```
Caller (any Node)
    │ INotificationSender (from HoneyDrunk.Notify.Abstractions)
    ▼
[Notify] — routes to the right channel based on notification type
    │
    ├─ Email path → Resend / SMTP gateway adapter
    └─ SMS path   → Twilio gateway adapter
    │
    ▼
[Transport] — (optional: queue-backed delivery for reliability)
    │ ITransportPublisher → enqueue notification message
    ▼
[Notify Worker] — Azure Functions consumer dequeues, retries, delivers
    │
    ▼
External channel (email inbox, SMS)

Telemetry ──────────────────────────────────► [Pulse] (delivery status, latency)
```

**Cross-repo ordering for changes:**
1. Kernel.Abstractions (if context changes)
2. Transport (if queue backend changes)
3. Notify (implementation changes)
4. Notify.Functions / Notify.Worker (deployment changes)

**Current status:** Notify is implemented but not deployed. Transport queue backend is stable.

---

## Flow 3: Telemetry Emission

**Repos touched:** Kernel → [Any Node] → Pulse  
**Trigger:** Any Grid operation (HTTP request, message handler, agent execution) emits telemetry.

```
[Any Node] — executes operation
    │ ITelemetryActivityFactory (from Kernel)
    │ Creates Activity (trace span) with GridContext enrichment
    │
    ▼
OpenTelemetry SDK (in-process)
    │
    ├─ Trace sink    → ITraceSink (Pulse contract)
    ├─ Log sink      → ILogSink
    └─ Metrics sink  → IMetricsSink
    │
    ▼
[Pulse.Collector] — OTLP collector, receives spans/logs/metrics
    │
    ├─ → Azure Monitor
    ├─ → Grafana / Prometheus
    └─ → Custom sinks (per Pulse.Sinks configuration)
```

**Key rule:** Nodes emit telemetry; Pulse routes it. Nodes never depend on Pulse at runtime — they depend on Kernel's `ITelemetryActivityFactory`. This keeps the telemetry pipeline replaceable without changing consumers.

**Current status:** Pulse.Collector is implemented, awaiting production deployment.

---

## Flow 4: Secret Resolution

**Repos touched:** Kernel → Vault → [Any Node]  
**Trigger:** A deployable Node needs a secret (API key, connection string, signing cert) at startup or per-operation.

```
Node startup
    │ AZURE_KEYVAULT_URI (env var — never hardcoded)
    ▼
[Vault] — bootstraps ISecretStore with Azure Key Vault provider
    │ IStartupHook (Kernel lifecycle)
    ▼
[Any Node] — resolves secret via ISecretStore
    │ ISecretStore.GetSecretAsync("secret-name")  ← no version pinning (invariant 21)
    ▼
Azure Key Vault → returns latest secret version
    │
    ├─ Cached in memory per ADR-0005
    └─ Event Grid invalidation via ADR-0006 when rotation occurs

Rotation event:
[Azure Key Vault] → Event Grid → [Vault.Rotation Function]
    │                               │
    │                               └─ rotates secret, updates Key Vault
    ▼
[Vault cache] → invalidated, next read resolves new version
```

**Cross-repo ordering for changes:**
1. Vault (if ISecretStore contract changes)
2. All consuming Nodes (Auth, AI, Operator, etc.)

**Current status:** Vault stable at 0.4.0. Vault.Rotation repo not yet scaffolded.

---

## Flow 5: Agent Task Execution (Target State — post AI sector launch)

**Repos touched:** Architecture → Actions → Agents → AI → Capabilities → Operator → Memory  
**Trigger:** Org Project board Status transitions to `Ready` on an agent-eligible issue.

```
[Org Project Board] — Status: Backlog → Ready (human action)
    │ projects_v2_item.edited webhook
    ▼
[HoneyDrunk.Actions] — cloud agent trigger workflow
    │ Checks out target repo + Architecture repo (for packet context)
    ▼
[Claude Agent SDK] — reads issue packet from Architecture/generated/issue-packets/
    │
    ▼
[HoneyDrunk.Agents] — agent lifecycle: register → initialize → execute
    │ IAgentExecutionContext, IAgentLifecycle
    │
    ├─ [HoneyDrunk.AI] — model inference (IChatClient, IModelProvider)
    │       │ Vault → model API keys
    │       └─ Pulse → inference telemetry
    │
    ├─ [HoneyDrunk.Capabilities] — tool resolution (IToolInvoker)
    │
    ├─ [HoneyDrunk.Memory] — context recall (IAgentMemory)
    │
    └─ [HoneyDrunk.Operator] — safety gate (approval if human-in-loop required)
    │
    ▼
Agent opens PR in target repo
    │
    ▼
[GitHub Actions] — PR triggers CI, tests, canary
    │ on merge:
    └─ Status → Done, issue closes
```

**Current status:** Actions trigger workflow is designed (ADR-0008 D8) but not fully implemented. All AI sector Nodes are Seed phase — this flow is the target state, not current state.

---

## Flow 6: Cross-Node Version Bump

**Repos touched:** Architecture → [Upstream Node] → [All Downstream Nodes]  
**Trigger:** A Core Node (typically Kernel) publishes a new version with breaking changes.

```
[Architecture repo] — scope agent decomposes the bump
    │ issue packets per downstream repo
    ▼
Wave 1: Upstream Node (e.g. Kernel) — bumps version, publishes to NuGet
    │ git tag → CI → NuGet push
    ▼
Wave 2: Direct consumers (Transport, Vault, Auth, Notify, Pulse)
    │ update PackageReference, update CHANGELOG, bump own version
    │ canary tests verify integration
    ▼
Wave 3: Indirect consumers (Web.Rest, Data, and any AI Nodes that depend on updated Nodes)
    │ same pattern
    ▼
Wave N: Grid-wide canary suite passes
```

**Execution order invariant:** Upstream must publish before downstream starts. Downstream canary tests validate the new version before PR merges. Never bump downstream before upstream is published.

**Key files:** `catalogs/relationships.json` (dependency order), `routing/execution-rules.md` (wave coordination).
