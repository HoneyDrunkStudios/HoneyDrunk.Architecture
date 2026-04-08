# HoneyDrunk.Evals — Overview

**Sector:** AI  
**Version:** TBD  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Evals`

## Purpose

Evaluation and quality layer for AI behavior. Runs prompts against models, scores outputs, detects regressions, and compares performance across providers. The quality gate that ensures AI changes don't silently degrade.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Evals.Abstractions` | Abstractions | Zero-dependency evaluation contracts |
| `HoneyDrunk.Evals` | Runtime | Evaluation engine, scoring, regression detection |

## Key Interfaces

- `IEvaluator` — Run an evaluation suite, return scored results
- `IEvalDataset` — Collection of eval cases with expected outputs
- `IEvalScorer` — Scoring function (automated or model-as-judge)
- `IEvalReport` — Structured evaluation results

## Design Notes

Evaluation results are emitted as Pulse signals. HoneyHub can consume these to detect quality regressions tied to specific deployments or model changes, closing the feedback loop between model updates and product quality. Supports both automated scoring (regex, schema validation) and model-as-judge scoring (using AI to evaluate AI).
