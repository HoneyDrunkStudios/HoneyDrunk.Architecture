# HoneyDrunk.Operator — Overview

**Sector:** AI  
**Signal:** Planned  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Operator`

## Purpose

Human control plane for the Hive. Provides approval gates, safety controls, circuit breakers, cost controls, incident intervention, audit trail, and decision authority for all AI operations. The only Node with authority to halt other AI Nodes.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Operator.Abstractions` | Abstractions | Zero-dependency control contracts |
| `HoneyDrunk.Operator` | Runtime | Policy engine, circuit breakers, audit log, cost guards |

## Key Interfaces

- `IApprovalGate` — Request approval, check status, receive decision
- `ICircuitBreaker` — Trip, reset, check state
- `ICostGuard` — Check budget, record spend, enforce limits
- `IAuditLog` — Append-only log of actions and decisions
- `IDecisionPolicy` — Rules for auto-approve, auto-deny, or require-human
- `ISafetyFilter` — Validate outputs before they leave the system

## Design Notes

Operator does not participate in reasoning — it observes and constrains. The system that decides what to do must never be the system that decides whether it's allowed to do it. This separation is critical for auditable AI safety. Operator must be independently deployable so safety rules can be updated without redeploying agents.
