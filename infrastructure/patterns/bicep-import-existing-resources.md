# Pattern: Importing existing resources to Bicep (ADR-0077 D6)

**Applies to:** ADR-0077 D6 (amended 2026-06-02), ADR-0077 D7.
**Supersedes:** the registry-shaped predecessor (packet 09).

The canonical playbook for the ADR-0077 D6 opportunistic-migration path: when a
manually-provisioned Azure resource needs a configuration change, the operator
imports it to Bicep **before** applying the change. The four-step path —
export → decompile → reconcile → adopt — is unchanged from the original; the
2026-06-02 amendment changes only **where** imported templates land
(`HoneyDrunk.Infrastructure`, not the Node's own repo) and **how** modules are
referenced (local relative path, no registry).

This is a **playbook, not an import** — it imports no specific resource. Actual
imports are per-import work with their own packets.

---

## Purpose

ADR-0077 D6 (unchanged by the amendment) commits the grandfather /
opportunistic-import posture. Verbatim:

> - **New infrastructure goes through Bicep from day one.**
> - **Existing resources are imported to Bicep opportunistically.** When an
>   existing resource needs a configuration change, the operator authors a Bicep
>   template for it as part of the change. The migration path: export the
>   existing resource to ARM JSON (`az resource show --ids ... --query
>   properties`), decompile it to Bicep (`az bicep decompile --file
>   resource.json`), reconcile drift between the decompiled template and the
>   desired state, and adopt the resource into the deploy pipeline thereafter.
> - **A per-Node import-to-Bicep packet** is filed when the Node's next
>   significant infrastructure work happens; not a campaign.

The greenfield counterpart is the
[node leaf-template scaffold](node-leaf-template.md) (packet 15): use **that**
when the resource does not yet exist; use **this** playbook when it already
exists and needs to come under IaC.

## When this playbook applies (and when not)

**Applies when:**

- An existing manually-provisioned resource needs a configuration change (the
  change is the natural touchpoint that triggers the import).
- An existing resource is structurally in scope for the substrate but not yet
  under IaC, and a significant infrastructure touchpoint has arrived.

Existing resources to import opportunistically include the early Vault
namespaces, the existing Service Bus namespaces, and the existing `dev` platform
resources (`acrhdshared{dev}`, `cae-hd-dev`) — the last is the first natural
import target and is cross-referenced from the `platform/` layer (packet 14).

**Does not apply to:**

- Brand-new resources — use the [leaf-template scaffold](node-leaf-template.md)
  (packet 15).
- Resources about to be deleted.
- Clean resources that already match module defaults with no pending change —
  the grandfather posture means there is **no retroactive campaign**; import at
  the next touchpoint, not before.

## The four-step path

### Step 1 — Export

```bash
az resource show --ids <resource-id> --output json > snapshot.json
```

Save the ARM snapshot. **Scrub or `.gitignore` anything sensitive** — the
snapshot can contain secret-shaped properties; those never enter a committed
template (see Step 3 and ADR-0077 D7 / invariant 91). Capture the non-default
configuration that distinguishes this resource from a fresh module call.

The snapshot is also the **rollback artifact** — see the rollback path below.

### Step 2 — Decompile

```bash
az bicep decompile --file snapshot.json
```

This produces ARM-shaped Bicep — a **starting point, not the final template.**
It inlines the raw resource declaration; the next step rewrites it into the
module-library shape.

### Step 3 — Reconcile drift (two reconciliations)

**3a — Library-shape reconciliation.** Hand-rewrite the decompiled `.bicep` to
consume per-concern modules by **local relative path** — there is **no `br:`
registry reference**. For example, replace an inlined
`Microsoft.KeyVault/vaults` resource with a module call:

```bicep
// Replace the inline Microsoft.KeyVault/vaults resource with a module call.
// Local relative path — NO br: registry reference.
module nodeVault '../../modules/secrets/keyVault.bicep' = {
  name: 'nodeVault'
  params: {
    service: 'identity'                    // @maxLength(13)
    env: env
    tags: tags                             // the composed tag object (packet 15's pattern)
    location: location
    logAnalyticsWorkspaceId: platformLogAnalyticsId   // from platform/ outputs, not pasted
  }
}
```

In the same pass:

- Replace inline tags with the composed `tags` variable (the
  [leaf-template pattern](node-leaf-template.md)'s shape).
- Replace any inline secret-as-property with a Key Vault **URI** /
  `keyVaultSecret` reference (ADR-0077 D7 / invariant 91) — strip the secret
  value entirely; the template carries a non-secret reference, never the value.
- Replace hand-pasted shared-resource ARM IDs with `platform/` exported IDs
  (packet 14).

**3b — Drift reconciliation.** Compare the library-shaped template against the
desired state. For each drift, decide and **document the decision in the
per-import packet body**:

- **Desired-state-precedence** — Bicep updates the resource to the desired value
  (the deployed value was wrong / stale).
- **Deployed-state-precedence** — the template carries the deployed value (the
  deployed value is correct and the module default would change it).

### Step 4 — Adopt

Apply via the reusable `job-deploy-bicep.yml` (packet 16, consumed from
`HoneyDrunk.Actions`). **Run `az deployment group what-if` first** — review
every property Azure considers different before applying:

```bash
az deployment group what-if \
  --resource-group <rg> \
  --template-file nodes/<node>/main.bicep \
  --parameters nodes/<node>/parameters.<env>.bicepparam
```

`what-if` before apply is **load-bearing for import safety.** Review every
flagged property. **Immutable property differences** (kind, location, certain
SKUs) mean **recreate-not-update** — Azure would delete and recreate the
resource. Fix the template to match the deployed immutable property rather than
let `what-if` schedule a destructive replace. Only apply once the `what-if`
delta is understood and intentional.

## Where imported templates land (amendment)

- **Node-owned resources** → `HoneyDrunk.Infrastructure/nodes/{node}/main.bicep`.
- **Shared-foundation resources** → `HoneyDrunk.Infrastructure/platform/main.bicep`
  (e.g. the existing `dev` platform resources — cross-reference packet 14).

**NOT** in the Node's own repo — the 2026-06-02 amendment relocated all Bicep
content into `HoneyDrunk.Infrastructure`.

## Per-import responsibilities

- The per-import packet is **filed by the `scope` agent** when the operator
  declares the trigger (the natural touchpoint).
- Its `target_repo` is **`HoneyDrunk.Infrastructure`** (not the Node's own repo —
  changed by the amendment).
- Its body **documents the per-resource drift decisions** (Step 3b — which
  drifts took desired-state vs deployed-state precedence, and why).
- Acceptance includes a successful `what-if` **and** apply on at least `dev`.

## `grid-health.json` reconciliation

Once imported, mark the resource Bicep-managed in `catalogs/grid-health.json`.
Inspect the catalog's current node/resource shape at execution time and follow
the existing structure — do not invent a new field layout. (If the import
**fails** and the resource stays manually provisioned, record that instead — see
the rollback path.)

## Common failure modes

- **Immutable property mismatch** — `kind`, `location`, certain SKUs are
  immutable. `what-if` shows a delete+create. Fix the template to match the
  deployed value; do not apply a destructive replace.
- **Missing tags** — the first apply adds the `hd:*` tags the manually
  provisioned resource lacks. This is **desirable drift** — let it apply.
- **Secrets surfaced in decompiled output** — the decompiled `.bicep` /
  `snapshot.json` may contain secret-shaped properties. **Strip them → Vault
  references** (D7 / invariant 91); never commit the value.
- **Resource-group mismatch** — the deploy targets the RG the resource actually
  lives in; confirm `--resource-group` matches the snapshot's scope.
- **Existing role assignments** — RBAC assignments on the resource may need to be
  represented or deliberately left out of scope; note the decision in the packet.

## Rollback path

- **Before the first apply** — revert the PR. No Azure state changed; the
  resource stays exactly as manually provisioned.
- **After the first apply** — re-apply the captured ARM snapshot from Step 1
  (the **ARM-snapshot safety net**), or roll forward with a corrected template.
- **Escape hatch (bidirectional grandfather).** A resource that fails import
  cleanly **stays manually provisioned** — note it in `grid-health.json` as
  not-yet-Bicep-managed. Under D6 the grandfather posture is **bidirectional**:
  the Grid converges on Bicep-managed-everything at natural touchpoints, and a
  resource that resists import waits for a later, cleaner touchpoint rather than
  forcing a risky migration.

## Cross-references

- [Node leaf-template scaffold](node-leaf-template.md) (packet 15) — the
  greenfield counterpart and the source of the `tags` / module-call shape this
  playbook reconciles toward.
- The `platform/` shared-foundation layer (packet 14) — the import target for
  shared resources (e.g. the existing `dev` platform resources) and the source
  of the exported IDs leaf/imported templates consume.
- The reusable deploy workflow `job-deploy-bicep.yml` in `HoneyDrunk.Actions`
  (packet 16) — runs the `what-if` preflight + apply.
- `HoneyDrunk.Infrastructure/modules/*/README.md` — the real per-concern module
  parameter contracts to reconcile decompiled resources toward.
- The existing [`infrastructure/walkthroughs/`](../walkthroughs/) portal
  runbooks — the manual-provisioning procedures these imports supersede over time.
