# HoneyDrunk.Evals — Active Work

**Initiative:** `adr-0023-evals-standup`

## In flight

- **Stand-up (ADR-0023)** — scaffold PR open on `claude/node-evals-standup-tvu57v`: solution, three
  packages (`Abstractions`, runtime, `Providers.InMemory`), the six D3 surfaces, `DefaultEvaluator`,
  `ChatTarget` (D6), rubric + model-as-judge scorers, observation-only Operator/Audit observers (D7),
  `EvalsTelemetry` (D10 carve-out), in-memory report store + suite repo, five CI workflows + the
  contract-shape canary. Awaiting merge → `v0.1.0` tag → first NuGet publish.

## Blocked on

- `HoneyDrunk.Operator.Abstractions 0.1.0` publish (Operator standup PR, same branch) — the runtime
  references it; CI restore is red until Operator merges and tags.

## Deferred follow-ups

- Concrete `AgentTarget` / `RetrievalTarget` / `MemoryTarget` shapes (per D3) — filed when downstream
  consumers drive them.
- Production `EvalReport` store (Data / Pulse-backed / dedicated provider) per D13 — filed when
  HoneyHub or a production regression workflow needs durability beyond `Providers.InMemory`.
- SonarCloud onboarding follow-up after merge + tag.
