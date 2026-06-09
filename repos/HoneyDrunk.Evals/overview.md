# HoneyDrunk.Evals — Overview

**Sector:** AI  
**Version:** 0.1.0 (scaffolded — ADR-0023)  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Evals`

## Purpose

Evaluation and quality substrate for AI behavior. Runs a suite of cases against a target, scores outputs, detects regressions, and compares models. The quality gate that ensures AI changes don't silently degrade.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Evals.Abstractions` | Abstractions | Evaluation contracts (D3). References only `HoneyDrunk.Kernel.Abstractions` (TenantId) and `HoneyDrunk.AI.Abstractions` (model surfaces) per ADR-0023 D2. |
| `HoneyDrunk.Evals` | Runtime | DefaultEvaluator, ChatTarget (D6 router-bypass), rubric + model-as-judge scorers, observation-only Operator scoring (D7), EvalsTelemetry (D10 carve-out). |
| `HoneyDrunk.Evals.Providers.InMemory` | Provider | In-memory `EvalReport` store + suite fixtures. |

## Contracts (ADR-0023 D3 — definitive set)

- `IEvaluator` — run a suite of cases against a target, produce an `EvalReport`
- `IEvalScorer` — scoring function (automated or model-as-judge), marked deterministic vs not
- `IEvalSuite` — named, versioned collection of `EvalCase`s with a rubric and sensitivity flag (D10)
- `IEvalTarget` — the thing under evaluation; owns the D6 router-bypass model pin
- `EvalCase` *(record)* — a single case: input, expected/rubric, metadata, `TenantId`
- `EvalReport` *(record)* — structured results with full run provenance (D12); durable (D13)

> Supersedes the earlier drifted prose (`IEvalDataset`, `IEvalReport`). `IEvalDataset` → `IEvalSuite`; `IEvalReport` → `EvalReport` (record, no `I` prefix); `IEvalTarget`, `EvalCase` added.

## Design Notes

Evaluation results are emitted as Pulse signals (no runtime edge to Pulse). Per the D10 carve-out, eval signals MAY carry prompts and outputs unless the suite declares itself sensitive. `EvalReport` is the durable artifact (D13); `Providers.InMemory` is the first-wave backend. Model-as-judge scoring composes `IChatClient` from `HoneyDrunk.AI.Abstractions`. Operator's `ISafetyFilter` / `ICostGuard` are composed observation-only (D7) — Evals observes, never enforces.
