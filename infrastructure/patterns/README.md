# Infrastructure Patterns

Reusable Infrastructure-as-Code scaffolding and migration patterns for the
ADR-0077 Bicep rollout (amended 2026-06-02). These are the canonical references
the `scope` agent and operators consult when provisioning or migrating Azure
resources.

Under the amendment, **all** Bicep content lives in the consolidated
[`HoneyDrunk.Infrastructure`](https://github.com/HoneyDrunkStudios/HoneyDrunk.Infrastructure)
repo: per-concern `modules/`, the shared-foundation `platform/` layer, and the
per-Node `nodes/{node}/` leaf templates. Modules are consumed by **local
relative path** — there is no Bicep module registry (`acrhdbicep` and the
`br:` publish flow were dropped). The reusable deploy + lint workflows stay in
`HoneyDrunk.Actions` per ADR-0012.

## Patterns

- **[Node leaf-template scaffold](node-leaf-template.md)** — the canonical
  `nodes/{node}/` layout, `main.bicep` skeleton (local-path module refs +
  `platform/` exported-ID references), `parameters.{env}.bicepparam` shape, and
  the consumer-side `pr.yml` lint + `job-deploy-bicep.yml` deploy wiring with
  ADR-0033 environment gates. Use this for **greenfield** infrastructure.
- **[Importing existing resources](bicep-import-existing-resources.md)** — the
  ADR-0077 D6 opportunistic-migration playbook: export → decompile → reconcile
  → adopt, targeting `HoneyDrunk.Infrastructure`. Use this when an existing
  **manually-provisioned** resource needs to come under IaC.

## References

- [ADR-0077: Infrastructure as Code (Bicep)](../../adrs/ADR-0077-infrastructure-as-code-bicep.md)
- [ADR-0012: Actions as CI/CD Control Plane](../../adrs/ADR-0012-grid-cicd-control-plane.md)
- [ADR-0033: Environment-Gated Deploy Trigger Model](../../adrs/ADR-0033-environment-gated-deploy-trigger-model.md)
- [ADR-0036: Disaster Recovery and Backup Policy](../../adrs/ADR-0036-disaster-recovery-and-backup-policy.md)
- [Grid Invariants](../../constitution/invariants.md) — especially 17–22, 34–36, 90–92.
- `HoneyDrunk.Infrastructure/modules/*/README.md` — the real per-concern module
  parameter contracts the patterns reference.
