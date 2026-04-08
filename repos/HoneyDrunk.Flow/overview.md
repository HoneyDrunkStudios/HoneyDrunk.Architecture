# HoneyDrunk.Flow — Overview

**Sector:** AI  
**Signal:** Planned  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Flow`

## Purpose

Execution-level workflow engine for the Grid. Manages multi-step pipelines, long-running processes, retry and compensation, agent chaining, and checkpoint/resume with human-in-the-loop approval.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Flow.Abstractions` | Abstractions | Zero-dependency workflow contracts |
| `HoneyDrunk.Flow` | Runtime | Workflow execution, state persistence, compensation |

## Key Interfaces

- `IWorkflow` — Workflow definition (steps, transitions, compensation)
- `IWorkflowEngine` — Execute, pause, resume, cancel workflows
- `IWorkflowStep` — Single step (may invoke an agent, tool, or external service)
- `IWorkflowState` — Persistent state for a running workflow
- `ICompensation` — Rollback logic for a failed step

## Design Notes

Flow operates at seconds/minutes/hours timescale — runtime execution. HoneyHub operates at days/weeks — planning and decomposition. HoneyHub decides *what* workflows to run. Flow runs them. Workflows persist state via Data and can pause for human approval via Operator's `IApprovalGate`.
