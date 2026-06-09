---
name: Operator Production Wiring Validation (fail-fast audit/auth/data)
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Operator
labels: ["feature", "tier-2", "ai", "operator", "audit", "adr-0018", "safety", "follow-up"]
dependencies: ["packet:03", "packet:04", "packet:05"]
adrs: ["ADR-0018", "ADR-0030", "ADR-0031"]
wave: 4
initiative: adr-0018-operator-standup
node: honeydrunk-operator
gates: ai-sector-enforcement-adoption
---

# Feature: Fail fast on missing Audit/Auth/Data wiring in production composition

## Summary

`OperatorAuditWriter` deliberately **degrades to a no-op when no audit sink is composed** (v0.1.0 design, unit-tested), so safety/cost/approval decisions can silently produce no audit evidence if a host forgets to wire Audit. The ADR-0086 Grid review verdict on Operator #13 flagged this as unacceptable for a production Operator. This packet adds a production-mode composition guard — `AddHoneyDrunkOperator()` validates that the required host services (Audit sink, Auth, Data) are present and **fails fast at startup** — while keeping the no-op path available for test-only setups. This was the verdict's own suggested remediation.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Operator`

## Motivation

Operator's value is that its decisions are authorized, enforced, durable, and **audited**. Silent absence of audit (or, after packets 04/05, Auth/Data) turns a safety substrate into a permissive pass-through with no evidence trail. The graceful-degrade default is correct for the `Testing` fixtures and unit tests, but production composition should make missing safety wiring impossible rather than invisible.

## Proposed Implementation

- Add an explicit production-mode signal to `AddHoneyDrunkOperator()` (e.g. an `OperatorOptions.RequireSafetyServices` flag, defaulting on outside test hosts, or a dedicated `AddHoneyDrunkOperator(production: true)` overload).
- In production mode, validate at startup (options validation / `IValidateOptions` or a hosted startup check) that:
  - at least one `IAuditLog` sink is registered (no silent no-op);
  - Auth delegation is composed (once packet 04 lands);
  - the Data persistence edge is composed (once packet 05 lands).
- On a missing required service, throw a clear, actionable startup exception naming the missing edge — never start with safety services absent.
- Keep `OperatorAuditWriter`'s no-op behavior reachable only in test-only / explicitly-opted-out composition; the `Testing` fixtures continue to work with zero host wiring.

## Acceptance Criteria

- Composing Operator in production mode with no `IAuditLog` throws at startup with a message identifying the missing audit sink.
- Test-only composition (and the `Testing` fixtures) still resolve with no Audit/Auth/Data wiring.
- After packets 04/05 land, the same guard covers missing Auth and Data edges.
- Unit tests cover present-services (starts), missing-audit (throws), and test-mode (no throw).

## Notes

- Sequencing: the audit portion can land independently; the Auth/Data portions activate as packets 04/05 complete. Until then, gate only on the audit sink and stub the Auth/Data checks behind the same flag.
- This packet, together with 04 and 05, clears the ADR-0086 verdict's blocking concerns for promoting Operator from a documented-deferral scaffold to an enforcement-grade baseline.
