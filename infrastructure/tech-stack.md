# Tech Stack

Canonical reference for all technology used across the HoneyDrunk Grid.

**Last Updated:** 2026-03-22

---

## Backend

| Technology | Version | Used By |
|-----------|---------|---------|
| .NET | 10.0 | All Nodes and Services |
| C# | 14 (`LangVersion: latest`) | All .NET projects |
| ASP.NET Core | 10.0 | Web.Rest, Pulse.Collector, Auth |
| Entity Framework Core | 10.0.3 | Data |
| Azure Functions (dotnet-isolated) | .NET 10.0 | Notify.Functions |
| gRPC | Grpc.AspNetCore 2.76.0 | Pulse.Collector |

### C# Language Features

Primary constructors, file-scoped namespaces, implicit usings, nullable reference types, pattern matching — enforced via HoneyDrunk.Standards.

---

## Frontend

| Technology | Version | Used By |
|-----------|---------|---------|
| Next.js | 16.0.0 | Studios website |
| React | 19.1.0 | Studios website |
| TypeScript | 5.x | Studios website |
| Tailwind CSS | 4.x | Studios website |
| Three.js | 0.180.0 | Studios website (3D visuals) |
| @react-three/fiber | 9.4.0 | Studios website |
| Framer Motion | 12.23.24 | Studios website (animations) |
| Turbopack | Built-in (Next.js) | Studios website (dev + build) |

---

## Testing

| Technology | Version |
|-----------|---------|
| xUnit | 2.9.3 |
| FluentAssertions | 8.8.0 |
| Moq | 4.20.72 |
| NSubstitute | 5.3.0 |
| Microsoft.NET.Test.SDK | 18.0.1 |
| coverlet.collector | 8.0.0 |

---

## Observability

| Technology | Version | Purpose |
|-----------|---------|---------|
| OpenTelemetry | 1.15.0 | Traces, metrics, logging |
| OpenTelemetry.Exporter.OTLP | 1.15.0 | Export to Pulse.Collector |
| OTel ASP.NET Core instrumentation | 1.15.0 | Auto-instrument HTTP |
| OTel HTTP instrumentation | 1.15.0 | Outbound HTTP tracing |
| OTel Runtime instrumentation | 1.15.0 | GC, threads, memory |

---

## Azure SDK

| Technology | Version | Used By |
|-----------|---------|---------|
| Azure.Messaging.ServiceBus | 7.20.1 | Transport.AzureServiceBus |
| Azure.Storage.Queues | 12.25.0 | Transport.StorageQueue |
| Azure.Storage.Blobs | 12.27.0 | Notify |
| Azure.Security.KeyVault.Secrets | 4.8.0 | Vault.Providers.AzureKeyVault |
| Azure.Identity | 1.17.1 | All Azure-integrated services |
| Azure.Core | 1.50.0 | Transitive |

---
## Resilience

| Technology | Version | Used By |
|-----------|---------|--------|
| Microsoft.Extensions.Resilience | 10.2.0 | Vault |
| Polly (transitive via above) | 8.x | Vault (retry + circuit breaker) |

Transport has its own built-in retry/backoff — it does not use Polly.

---
## Identity and Auth

| Technology | Version |
|-----------|---------|
| Microsoft.IdentityModel.JsonWebTokens | 8.15.0 |
| ULID (via Ulid package) | 1.4.1 |

---

## Code Quality

| Technology | Version | Purpose |
|-----------|---------|---------|
| HoneyDrunk.Standards | 0.2.6 | BuildTransitive analyzer package for all repos |
| StyleCop.Analyzers | Bundled in Standards | Naming, ordering, documentation |
| Microsoft.CodeAnalysis.NetAnalyzers | 10.0.x | Performance, reliability, security |
| Warnings as errors | Enforced | CI gate |
| Nullable reference types | Enabled globally | Null safety |
| Deterministic builds | Enabled | Reproducible binaries |

---

## CI/CD

| Technology | Version | Purpose |
|-----------|---------|---------|
| GitHub Actions | N/A | All CI/CD |
| HoneyDrunk.Actions | Reusable workflows | Standardized build, test, deploy |
| actions/checkout | v4 | Source checkout |
| actions/setup-dotnet | v4 | .NET SDK setup |
| actions/upload-artifact | v4 | Artifact sharing |

---

## Containers

| Base Image | Used By |
|-----------|---------|
| `mcr.microsoft.com/dotnet/aspnet:10.0` | Pulse.Collector (runtime) |
| `mcr.microsoft.com/dotnet/runtime:10.0` | Notify.Worker (runtime) |
| `mcr.microsoft.com/dotnet/sdk:10.0` | Build stage (both) |

---

## Hosting

| Target | Used By |
|--------|---------|
| Azure App Service (container) | Pulse.Collector |
| Azure Functions | Notify.Functions |
| Docker / GHCR | Pulse.Collector, Notify.Worker |
| Vercel | Studios website |
| NuGet.org | All Node packages |

See [deployment-map.md](../infrastructure/deployment-map.md) for full deployment details.

---

## Planned / Future

### Developer Experience

| Technology | Target | Context |
|-----------|--------|--------|
| .NET Aspire | Q2–Q3 2026 | Local dev orchestration for the multi-service Grid. Launches Pulse.Collector, Notify, backing infra in one command. Built-in dashboard for traces/logs/metrics, service discovery, and health aggregation. Complements Kernel's own service discovery for inner-loop dev. |
| Scalar | Q2 2026 | Modern OpenAPI UI — replacement for deprecated Swashbuckle. ASP.NET Core 10 has built-in OpenAPI generation; Scalar provides the interactive UI. Relevant for Web.Rest and Pulse.Collector. |

### AI / Agents

| Technology | Target | Context |
|-----------|--------|--------|
| Microsoft.Extensions.AI | Q3 2026 | .NET's `IChatClient` / `IEmbeddingGenerator` abstractions — provider-agnostic AI integration for Agent Kit. |
| Semantic Kernel | Q3 2026 | AI orchestration framework for Agent Kit Node — plugins, planners, memory, function calling. Builds on Microsoft.Extensions.AI. |

### Performance

| Technology | Target | Context |
|-----------|--------|--------|
| Native AOT | Q3 2026 | Faster cold starts for Azure Functions (Notify), potential for CLI tools and WASM modules. .NET 10 AOT support is production-ready. Requires serialization audit (source generators). |
| Rust | Future | Performance-critical paths (CLI tools, WASM modules, compute-heavy processing). |

### Testing

| Technology | Target | Context |
|-----------|--------|--------|
| Testcontainers | Q2 2026 | Real database/broker integration tests. Already recommended in Data docs. Drop-in Docker containers for SQL Server, Service Bus emulator, etc. |
| BenchmarkDotNet | Q2 2026 | Performance regression tracking. Already in .gitignore and Kernel docs with sample benchmarks. Needs a `*.Benchmarks` project per Node. |
| Verify | Future | Snapshot testing for public API surface stability in Abstractions packages. Catches accidental contract-breaking changes. |

### Infrastructure

| Technology | Target | Context |
|-----------|--------|--------|
| YARP | Future | Reverse proxy with middleware pipeline — natural backing for the planned Gateway Node. |
| WebSocket / SignalR transport | Q3 2026 | Grid v0.5 evaluation |
| gRPC transport provider | Q3 2026 | Grid v0.5 |
| Cosmos DB | Q4 2026 | Data Node provider |
| Redis / distributed cache | Future | HoneyDrunk.Cache abstraction |
| Kubernetes | Future | Container orchestration |
| Grafana | Q2 2026 | Pulse dashboard templates |
| Saga / compensation patterns | Q2–Q3 2026 | Orchestrator Node |

### Mobile & Frontend

| Technology | Target | Context |
|-----------|--------|--------|
| React Native / Expo | Future | Mobile apps for HoneyHub and creator tools |

### Planned Nodes (no code yet)

| Node | Sector | Purpose |
|------|--------|---------|
| Agent Kit | AI | Agent execution runtime, tool abstraction, memory |
| Orchestrator | Core | Workflow orchestration, multi-step pipelines |
| HoneyHub | Creator | Project orchestration, creator dashboard |
| Gateway | Core | API gateway with Grid context |
| Jobs | Ops | Background job scheduling |
| Cache | Core | Distributed caching abstraction |

---

## How to Update This File

- **Version bump in a dependency:** Update the version in the relevant table.
- **New technology adopted:** Add to the appropriate section.
- **Technology removed:** Remove the row and note in the next release.
- **Planned tech becomes real:** Move from Planned to the appropriate current section.
