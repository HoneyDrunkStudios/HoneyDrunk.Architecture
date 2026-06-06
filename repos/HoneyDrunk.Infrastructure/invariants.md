# HoneyDrunk.Infrastructure — Invariants

This Node is governed by the Grid-wide invariants in `constitution/invariants.md`. The directly load-bearing ones:

## IaC invariants (ADR-0077)

1. **Invariant 90** — New Azure infrastructure is provisioned via Bicep. This Node is the home for that Bicep.
2. **Invariant 91** — Bicep templates never contain secret values. Templates reference secrets by Key Vault URI (ADR-0077 D7).
3. **Invariant 92** — Bicep templates apply the Grid naming and tagging conventions enforced by linter rules.

## Hosting Platform invariants

4. **Invariant 34** — Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment.
5. **Invariant 35** — One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`) serve every containerized Node. The `platform/` layer defines these shared resources.

## Naming and secrets

6. **Invariant 19** — Service names in Azure resource naming must be ≤ 13 characters.
7. **Invariant 8** — Secret values never appear in logs, traces, exceptions, or telemetry (and, by extension here, never in templates or parameter files).
