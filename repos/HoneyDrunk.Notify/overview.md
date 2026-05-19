# HoneyDrunk.Notify — Overview

**Sector:** Ops  
**Version:** 0.3.0
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Notify`

## Purpose

Channel-agnostic notification intake and delivery with multi-provider support. Notify handles structural validation, queue-backed intake, provider dispatch, retries, and delivery outcomes. Recipient preference, cadence, suppression, and workflow decisions belong in HoneyDrunk.Communications.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Notify.Abstractions` | Abstractions | Notification intake/delivery contracts |
| `HoneyDrunk.Notify` | Runtime | Intake and delivery engine |
| `HoneyDrunk.Notify.Functions` | Service | Azure Functions queue-triggered delivery host |
| `HoneyDrunk.Notify.Hosting.AspNetCore` | Hosting | ASP.NET Core integration |

## ADR-0019 Boundary Cleanup

v0.2.0 removed Notify-owned recipient policy evaluation (`INotificationPolicy`, `PolicyEvaluationResult`, `PolicyDenied`, default policy pipeline) and renamed the runtime `Orchestration/` area to `Intake/`. Notify is now the delivery Node; Communications is the decision Node.
