---
name: CI/CD Configuration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-2", "ci", "docs", "adr-0037", "payments", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0012", "ADR-0037", "ADR-0082"]
wave: 1
initiative: adr-0037-payments-standup
node: honeydrunk-actions
supersedes:
  - generated/work-items/active/adr-0037-payment-billing/01-architecture-billing-node-catalog-and-context.md
---

# Map HoneyDrunk.Payments to the Payments Node in Actions

## Summary

Add `HoneyDrunk.Payments: honeydrunk-payments` to `HoneyDrunk.Actions/.github/config/repo-to-node.yml`.

## Context

ADR-0012 makes `HoneyDrunk.Actions` the source of truth for shared CI/CD configuration, including `repo-to-node.yml`. ADR-0082 lists the repo-to-Node mapping as a mandatory Node standup step. Payments cannot be treated as fully registered until Actions knows how to map the repository to `honeydrunk-payments`.

## Scope

- Update `.github/config/repo-to-node.yml` in `HoneyDrunk.Actions`.
- Validate the YAML still parses as a simple repository-to-node mapping.
- Open a companion PR and link it from the Architecture registration PR.

## Acceptance Criteria

- [ ] `HoneyDrunk.Payments` maps to `honeydrunk-payments`.
- [ ] The Actions PR passes workflow lint / secret policy checks.
- [ ] The Architecture PR links the companion Actions PR.

## Constraints

- Do not move this mapping into Architecture; ADR-0012 assigns shared workflow configuration to Actions.
