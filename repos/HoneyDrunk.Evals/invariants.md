# HoneyDrunk.Evals — Invariants

Evals-specific invariants (supplements `constitution/invariants.md`).

1. **Evals.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **Evaluation datasets are versioned.**
   Changes to eval cases produce a new version. Results reference the dataset version they were scored against.

3. **Scoring is deterministic for automated scorers.**
   Given the same output and rubric, an automated scorer produces the same score. Model-as-judge scorers are explicitly marked as non-deterministic.

4. **Evaluation results are emitted as Pulse signals.**
   Every eval run produces structured telemetry so regressions can be correlated to deployments.

5. **Evals never modifies the model or prompt under test.**
   Evals is a read-only observer. It runs inputs, captures outputs, and scores them. No side effects.
