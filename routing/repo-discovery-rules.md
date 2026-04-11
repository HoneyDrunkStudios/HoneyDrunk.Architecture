# Repo Discovery Rules

Rules for determining which repo(s) are affected by a given request.

## Lookup Strategy

1. **Keyword Match** — Scan the request for Node names, package names, or sector names. Match against `catalogs/nodes.json`.
2. **Dependency Walk** — If a change affects a Node, check `catalogs/relationships.json` to find downstream consumers.
3. **Sector Scan** — If the request mentions a sector (e.g., "Core", "Ops", "Meta"), find all Nodes in that sector.
4. **Invariant Check** — If the request could violate an invariant from `constitution/invariants.md`, flag all affected repos.

## Keyword → Repo Mapping

| Keywords | Repo |
|----------|------|
| context, GridContext, NodeContext, OperationContext, lifecycle, startup hook, health contributor, correlation, identity, CorrelationId, NodeId | `HoneyDrunk.Kernel` |
| transport, message, publish, consume, envelope, middleware, outbox dispatcher, service bus, storage queue, broker | `HoneyDrunk.Transport` |
| vault, secret, ISecretStore, key vault, aws secrets, config provider | `HoneyDrunk.Vault` |
| rotation, secret rotation, IRotator, RotationResult, third-party rotation, Vault.Rotation | `HoneyDrunk.Vault.Rotation` |
| auth, JWT, token, authorization, policy, signing key, claims | `HoneyDrunk.Auth` |
| REST, API, response envelope, ApiResult, exception mapping, correlation header, pagination | `HoneyDrunk.Web.Rest` |
| telemetry, trace, metrics, logs, sink, Loki, Tempo, Mimir, PostHog, Sentry, OTLP, Pulse, collector | `HoneyDrunk.Pulse` |
| repository, unit of work, EF Core, SQL Server, tenant, data access, outbox store, migration | `HoneyDrunk.Data` |
| notification, email, SMS, SMTP, Resend, Twilio, notify, channel | `HoneyDrunk.Notify` |
| workflow, CI, GitHub Actions, pipeline, PR check, release | `HoneyDrunk.Actions` |
| website, Studios, Next.js, pages, blog | `HoneyDrunk.Studios` |
| architecture, ADR, invariant, sector, catalog, routing | `HoneyDrunk.Architecture` |

## Dependency Cascade Rules

When a change affects a Node's **Abstractions** package:
1. Identify all downstream Nodes from `catalogs/relationships.json`
2. Generate issue packets for each downstream Node to update their dependency
3. Order execution: upstream first, then downstream (Kernel → Transport → Vault → Auth → Web.Rest → Data)

When a change affects a Node's **runtime** package only:
- No cascade needed — downstream Nodes depend on Abstractions, not runtime.

## Ambiguity Resolution

If a request maps to multiple repos and the scope is unclear:
1. Ask the user to clarify
2. Default to the most upstream affected repo
3. If truly cross-repo, treat as `cross-repo-change` request type
