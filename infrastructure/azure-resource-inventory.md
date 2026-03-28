# Azure Resource Inventory

All Azure resources provisioned or planned across the HoneyDrunk Grid.

**Last Updated:** 2026-03-28

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
| App Service Plan | `plan-hd-notify-dev` | Pending | Consumption plan for the Function App |
| Storage Account | `sthdnotifydev` | Pending | Queues (notify-queue) + Function App runtime storage |
| Key Vault | `kv-hd-notify-dev` | Pending | Runtime secrets (see [azure-identity-and-secrets.md](azure-identity-and-secrets.md)) |
| App Registration | `sp-hd-notify-dev` | Pending | OIDC identity for GitHub Actions deployments |

### Pulse

| Resource | Name | Status | Purpose |
|----------|------|--------|---------|
| Resource Group | `rg-hd-pulse-dev` | Pending | Contains all Pulse dev resources |
| App Service | `app-hd-pulse-dev` | Pending | Runs Pulse.Collector (OTLP receiver, container) |
| App Service Plan | `plan-hd-pulse-dev` | Pending | Hosting plan for the collector container |
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

Resources shared across services within a subscription.

| Resource | Name | Status | Purpose |
|----------|------|--------|---------|
| — | — | — | None yet. Add here if shared resources are introduced (e.g., shared Service Bus namespace). |

---

## How to Update This File

- **Resource provisioned:** Change status from Pending to Provisioned.
- **New service:** Add a section under the appropriate subscription with all its resources.
- **New environment:** Add a new top-level section.
- **Resource decommissioned:** Remove the row or add a note.
