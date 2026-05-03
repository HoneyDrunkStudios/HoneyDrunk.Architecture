# Proposed ADRs and PDRs Awaiting Acceptance

Tracked automatically by the hive-sync agent. ADRs/PDRs with all implementing
issues closed are auto-flipped to Accepted on each run; the rest are listed
here with progress.

Last synced: 2026-05-03

## Awaiting (no `accepts:`-declaring packets yet)

These have no packets declaring them in `accepts:` frontmatter. Auto-flip
will not happen until the scope agent files at least one packet that
declares the decision in `accepts:`. Legacy Proposed ADRs whose
implementing packets pre-date the `accepts:` convention also appear here
and remain manually-flippable until rescoped.

| ID | Title | Sector | Dated | Days in Proposed |
|----|-------|--------|-------|------------------|
| [ADR-0011](../adrs/ADR-0011-code-review-and-merge-flow.md) | Code Review and Merge Flow | Meta | 2026-04-12 | 21 |
| [ADR-0012](../adrs/ADR-0012-grid-cicd-control-plane.md) | HoneyDrunk.Actions as the Grid CI/CD Control Plane | Meta | 2026-04-13 | 20 |
| [ADR-0013](../adrs/ADR-0013-communications-orchestration-layer.md) | Communications Orchestration Layer — HoneyDrunk.Communications | Ops | 2026-04-16 | 17 |
| [ADR-0016](../adrs/ADR-0016-stand-up-honeydrunk-ai-node.md) | Stand Up the HoneyDrunk.AI Node — Inference Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0017](../adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md) | Stand Up the HoneyDrunk.Capabilities Node — Tool Registry and Dispatch Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0018](../adrs/ADR-0018-stand-up-honeydrunk-operator-node.md) | Stand Up the HoneyDrunk.Operator Node — Human-Policy Enforcement and Audit Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0019](../adrs/ADR-0019-stand-up-honeydrunk-communications-node.md) | Stand Up the HoneyDrunk.Communications Node — Orchestration Substrate Above Notify | Ops | 2026-04-19 | 14 |
| [ADR-0020](../adrs/ADR-0020-stand-up-honeydrunk-agents-node.md) | Stand Up the HoneyDrunk.Agents Node — Agent Runtime Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0021](../adrs/ADR-0021-stand-up-honeydrunk-knowledge-node.md) | Stand Up the HoneyDrunk.Knowledge Node — External Knowledge Ingestion and Retrieval Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0022](../adrs/ADR-0022-stand-up-honeydrunk-memory-node.md) | Stand Up the HoneyDrunk.Memory Node — Agent-Memory Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0023](../adrs/ADR-0023-stand-up-honeydrunk-evals-node.md) | Stand Up the HoneyDrunk.Evals Node — Evaluation and Quality Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0024](../adrs/ADR-0024-stand-up-honeydrunk-flow-node.md) | Stand Up the HoneyDrunk.Flow Node — Workflow-Orchestration Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0025](../adrs/ADR-0025-stand-up-honeydrunk-sim-node.md) | Stand Up the HoneyDrunk.Sim Node — Simulation and Plan-Evaluation Substrate for the AI Sector | AI | 2026-04-19 | 14 |
| [ADR-0027](../adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) | Stand Up the HoneyDrunk.Notify.Cloud Node — Multi-Tenant Commercial Wrapper Above Notify | Ops | 2026-05-02 | 1 |
| [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) | HoneyDrunk Notify — First Commercial Product on the Grid | Ops (primary) · Meta (positioning) | 2026-05-02 | 1 |

## In Progress (implementing packets filed; some issues still open)

| ID | Title | Sector | Dated | Closed/Total | Days in Proposed |
|----|-------|--------|-------|--------------|------------------|
| [ADR-0014](../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) | Hive–Architecture Reconciliation Agent | Meta | 2026-04-16 | 1/6 | 17 |

## Pending Flip (qualified for auto-flip but exceeds MAX_FLIPS_PER_RUN this run)

> Flip queue exceeds the per-run limit (3); the entries below will flip on subsequent runs.

_None._

## Anomalies

Surface-only items. The agent does not act on these — the human/scope agent does.

| Category | ID / Item | Detail | First Surfaced |
|----------|-----------|--------|----------------|
| _None._ |  |  |  |

## Flipped This Run

ADRs/PDRs whose Status was changed by **this** sync run from `Proposed` to `Accepted`. Regenerated each run from the current run's flips only.

_None._
