# Azure Resource Inventory

All Azure resources provisioned or planned across the HoneyDrunk Grid.

**Last Updated:** 2026-04-25

---

## Status Key

| Status | Meaning |
|--------|---------|
| Provisioned | Resource exists and is configured |
| Pending | Needs to be created |
| — | Not applicable for this environment |

---

## HoneyDrunk Core — Development (`honeydrunk-dev`)

### Notify

| Resource | Name | Status | Purpose |
|----------|------|--------|---------|
| Resource Group | `rg-hd-notify-dev` | Pending | Contains all Notify dev resources |
| Function App | `func-hd-notify-dev` | Pending | Runs Notify.Functions (queue-triggered email/SMS) |
| Container App | `ca-hd-notify-worker-dev` | Pending | Runs Notify.Worker (queue-driven background service) on shared `cae-hd-dev` |
| Storage Account | `sthdnotifydev` | Pending | Queues (notify-queue) + Function App runtime storage |
| Key Vault | `kv-hd-notify-dev` | Pending | Runtime secrets (see [azure-identity-and-secrets.md](azure-identity-and-secrets.md)) |
| App Registration | `sp-hd-notify-dev` | Pending | OIDC identity for GitHub Actions deployments |

### Pulse

| Resource | Name | Status | Purpose |
|----------|------|--------|---------|
| Resource Group | `rg-hd-pulse-dev` | Pending | Contains all Pulse dev resources |
| Container App | `ca-hd-pulse-dev` | Pending | Runs Pulse.Collector (OTLP receiver, gRPC) on shared `cae-hd-dev` |
| Key Vault | `kv-hd-pulse-dev` | Pending | Runtime secrets |
| App Registration | `sp-hd-pulse-dev` | Pending | OIDC identity for GitHub Actions deployments |

---

## HoneyHub — Development (`honeyhub-dev`)

| Resource | Name | Status | Notes |
|----------|------|--------|-------|
| Subscription | `honeyhub-dev` | Provisioned | Separate subscription for HoneyHub resources |

Resources TBD as HoneyHub development progresses.

---

## Staging / Production

Not yet provisioned. Will mirror the development layout with `stg` / `prod` environment suffixes. See [azure-naming-conventions.md](azure-naming-conventions.md) for naming rules.

---

## Cross-Cutting Resources

Resources shared across services within a subscription. Provisioned once per environment.

### `honeydrunk-dev`

| Resource | Name | Status | Purpose |
|----------|------|--------|---------|
| Resource Group (platform) | `rg-hd-platform-dev` | Provisioned | Holds platform-shared resources (ACR, CAE, shared Log Analytics, App Configuration) |
| Container Registry | `acrhdshareddev` | Provisioned | Shared image registry for every containerized Node (Basic SKU) — see ADR-0015 |
| Container Apps Environment | `cae-hd-dev` | Pending | Consumption-only environment hosting every Container App in dev — see ADR-0015 |
| Log Analytics Workspace | `log-hd-shared-dev` | Provisioned | Diagnostics sink for every Node and platform resource |
| App Configuration | `appcs-hd-shared-dev` | Provisioned | Non-secret config store with per-Node label partitioning (Developer tier) |

---

## How to Update This File

- **Resource provisioned:** Change status from Pending to Provisioned.
- **New service:** Add a section under the appropriate subscription with all its resources.
- **New environment:** Add a new top-level section.
- **Resource decommissioned:** Remove the row or add a note.
