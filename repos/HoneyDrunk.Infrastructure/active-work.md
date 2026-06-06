# HoneyDrunk.Infrastructure — Active Work

## In-flight initiative

**ADR-0077 — IaC / Bicep rollout** (amended 2026-06-02). This Node is being stood up as part of the IaC consolidation. The repo is registered (this packet) and scaffolded; content lands across the bringup packets below.

## Bringup packets

| Packet | Scope | Status |
|--------|-------|--------|
| 10 | Catalog/governance registration of the Node (nodes/relationships/grid-health/contracts rows, routing keyword row, Ops sector row, this context folder). | This packet |
| 11 | Repo creation + in-repo scaffolding (`repo-to-node.yml`, `.honeydrunk-review.yaml`, `pr.yml`, branch protection, org-secret binding). | Done — scaffold |
| 13 | Per-concern module bodies under `modules/`. | Pending |
| 14 | Shared `platform/` layer (shared Container Apps Environment, image ACR, Log Analytics, Service Bus, networking). | Pending |
| 15 | Per-Node leaf-template pattern under `nodes/{node}/`. | Pending |

## Signal flip

The Node is registered at **signal Seed**. It flips to **Live** when packets 13 (module bodies) and 14 (platform layer) land content.
