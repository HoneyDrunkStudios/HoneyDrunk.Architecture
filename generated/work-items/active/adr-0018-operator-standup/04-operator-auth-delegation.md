---
name: Operator Auth Delegation (D5)
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Operator
labels: ["feature", "tier-2", "ai", "operator", "auth", "adr-0018", "safety", "follow-up"]
dependencies: ["work-item:03"]
adrs: ["ADR-0018", "ADR-0005"]
wave: 4
initiative: adr-0018-operator-standup
node: honeydrunk-operator
gates: ai-sector-enforcement-adoption
---

# Feature: Delegate `AuthBackedDecisionPolicy` to HoneyDrunk.Auth (ADR-0018 D5)

## Summary

`AuthBackedDecisionPolicy` currently resolves Allow / Deny / RequireApproval **from configuration only** (`HoneyDrunk:Operator:Policy:{action}`), with Auth delegation carried as `TODO(auth)` and listed under *Deferred* in the v0.1.0 CHANGELOG. This packet makes the policy delegate to HoneyDrunk.Auth so that a config-level `Allow` cannot bypass actor/resource authorization. This was raised as a blocker by the ADR-0086 Grid review verdict on Operator #13 and is an intentional v0.1.0 deferral, not a defect — but it **must land before any AI-sector Node relies on Operator for enforcement**.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Operator`

## Motivation

ADR-0018 D5 requires Operator's decision policy to be authorization-backed: the config table sets the *baseline* posture per action, but the final Allow/Deny must be checked against the acting identity and target resource via HoneyDrunk.Auth. Shipping enforcement that trusts config alone would let a misconfigured or over-broad `Allow` grant actions the actor is not authorized to perform — the exact failure mode Operator exists to prevent.

## Proposed Implementation

- Take a runtime dependency on `HoneyDrunk.Auth.Abstractions` (consume its authorization contract; do **not** redefine Auth types — invariant 1).
- In `AuthBackedDecisionPolicy.EvaluateAsync(ActionContext)`:
  - Resolve the config baseline as today.
  - Before returning `Allow`, delegate to Auth to confirm the `ActionContext.Actor` is authorized for `Action` on `Resource`. An Auth denial downgrades the outcome to `Deny` (or `RequireApproval` per policy), never escalates.
  - `Deny` and `RequireApproval` baselines are preserved (Auth cannot upgrade a denial to an allow).
  - Emit an audit entry for the Auth-driven downgrade path.
- Compose Auth in `AddHoneyDrunkOperator()`; keep a test-only permissive path via the `Testing` fixture (`PermissiveDecisionPolicy` already exists).

## Acceptance Criteria

- A config `Allow` for an action the actor is **not** authorized for resolves to `Deny`/`RequireApproval`, with an audit record.
- A config `Deny`/`RequireApproval` is never upgraded by Auth.
- Unknown actions still fail safe to `RequireApproval`.
- Unit tests cover allow-then-auth-denied, allow-then-auth-allowed, and the fail-safe default; coverage holds the Node floor.
- `TODO(auth)` removed from `AuthBackedDecisionPolicy` and the CHANGELOG *Deferred* entry resolved.

## Notes

- Depends on a stable HoneyDrunk.Auth authorization abstraction being published. If the needed Auth contract is not yet shipped, this packet is gated on that Auth surface (file the dependency edge in `catalogs/relationships.json`).
- Boundary: Operator consumes Auth's contract; it does not own authorization logic.
