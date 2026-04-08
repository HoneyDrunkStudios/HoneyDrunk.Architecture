# HoneyDrunk.Sim — Invariants

Sim-specific invariants (supplements `constitution/invariants.md`).

1. **Sim.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **Simulations have no side effects.**
   A simulation never modifies real state — no database writes, no message sends, no tool executions against live systems.

3. **Risk assessments include confidence levels.**
   Every `IRiskAssessment` result includes a confidence indicator so consumers know the reliability of the projection.

4. **Simulation results are not cached as production data.**
   Sim outputs are ephemeral projections, not facts. They are never stored in Knowledge or Memory as ground truth.

5. **GridContext distinguishes simulation from real execution.**
   Simulation runs carry a flag in context so downstream systems can differentiate sim traffic from real traffic.
