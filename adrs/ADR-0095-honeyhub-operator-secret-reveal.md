# ADR-0095: HoneyHub Operator Plaintext Secret Reveal

**Status:** Proposed
**Date:** 2026-06-22
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform
**Relationships:** Scopes a governance carve-out on top of [ADR-0090](ADR-0090-honeyhub-local-runner-bridge.md) (local runner bridge), [ADR-0091](ADR-0091-honeyhub-app-stack-and-repo-node-home.md) (app stack / Node home), [ADR-0092](ADR-0092-honeyhub-session-usage-telemetry-and-routing.md) (session/usage), and the HoneyHub Connectors Framework ([ADR-0094](ADR-0094-honeyhub-connectors-framework.md), Proposed). Relates to the Grid secret-handling discipline in [ADR-0005](ADR-0005-configuration-and-secrets-strategy.md) (configuration and secrets strategy) and [ADR-0006](ADR-0006-secret-rotation-and-lifecycle.md) (secret rotation and lifecycle). Tracked in the [HoneyHub program](../initiatives/programs/honeyhub.md).

---

## Context

HoneyHub PR #47 (merged, squash `cd1aea2`) shipped an operator-facing capability: on an explicit per-secret "Reveal" action, the cockpit displays the plaintext value of an Azure Key Vault *secret* that the operator can already read through their own `az` session on the bridge host. This is the operator-directed "view Key Vault secrets" feature the operator explicitly asked for, layered onto the ADR-0094 Connectors / Service Bus / vault-browse surface.

The Grid Review Runner (ADR-0086 / ADR-0044) BLOCKED the PR on governance grounds. The synthesized verdict was "Block / Requires ADR: Yes": a surface that puts a plaintext secret value on screen crosses two standing disciplines without an explicit decision of record.

1. **Grid secret-source discipline.** Invariant 9 makes `ISecretStore` the only source of secrets for Grid Nodes, and ADR-0005 / ADR-0006 build the entire enterprise secret posture (per-Node vaults, Managed Identity, rotation SLAs, audit) on top of it. A surface that reads and renders secret plaintext looks, at first glance, like a second secret-source path that bypasses that discipline.

2. **Secret-leakage discipline.** Invariant 8 says secret values never appear in logs, traces, exceptions, or telemetry. A reveal feature that is careless about logging, persistence, or sync would violate invariant 8 directly, and HoneyHub's own data-minimization posture (ADR-0090 D8/D11: "no secret values streamed into HoneyHub transcripts," state-only notifications, local-first data) compounds the concern.

The operator override-merged because the feature is operator-directed and lives entirely inside the local-first cockpit, and chose to document the carve-out via this ADR rather than revert. This ADR is that record. It does not introduce a new capability; it states the governance boundary the shipped capability must stay inside, so the carve-out is explicit, auditable, and review-stable on the next pass.

This is a workshop tool for a single operator inspecting infrastructure they already own (charter: the Grid exists so the operator can build and operate cool things; the discipline is intrinsic, not customer-demanded). The carve-out is sized for that reality, not for a multi-tenant secret-handling product surface.

---

## Decision

### D1. Scope: operator self-service inspection of secrets the operator already controls

HoneyHub MAY, on an explicit per-secret operator action ("Reveal"), display the plaintext value of an Azure Key Vault **secret** (kind = secret only; never keys, never certificates, never their private material) that the operator can already read via their own `az` CLI session on the bridge host.

This is read-through inspection of the operator's own Azure RBAC. It is not a new secret source. HoneyHub does not store, broker, cache, rotate, or re-serve these values, and no Grid service consumes them. The value's authority remains 100 percent in the operator's Key Vault plus their own RBAC grant; HoneyHub is a momentary lens onto a value the operator could already print with one `az keyvault secret show` command.

### D2. Why this is acceptable outside `ISecretStore` and the Grid secret-source discipline

Invariant 9 ("Vault is the only source of secrets") governs **Grid Nodes consuming secrets to do their runtime work**: a Node must obtain its operational credentials through `ISecretStore`, never from raw env vars, config files, or provider SDKs. The reveal surface is categorically different and does not fall under invariant 9, because:

- **No Grid Node consumes the revealed value.** Nothing in the Grid runtime binds, injects, or authenticates with it. It is shown to a human and then discarded. There is no `IOptions<T>` target, no service, no broker.
- **HoneyHub is not acting as a secret store.** It does not persist, cache, broker, rotate, or re-serve the value. `ISecretStore` exists to be the single brokered path for *programmatic* secret consumption; a human reading their own vault entry is not that path and was never what invariant 9 was written to constrain.
- **The authority and the access decision both stay in Azure.** Data-plane access is the operator's own `az keyvault secret show` under their host session and their RBAC. If the operator lacks `Key Vault Secrets User` (or equivalent), the reveal fails at Azure. HoneyHub adds no privilege; it cannot reveal anything the operator could not already read.
- **This is the local-first cockpit boundary (ADR-0090 / ADR-0091).** HoneyHub v1 is local-first: the bridge runs on the operator's own machine or the ADR-0086 runner host, paired explicitly (ADR-0090 D8), with no hosted backend (ADR-0091). The reveal value never leaves that boundary.

Relationship to ADR-0005 / ADR-0006: those ADRs are unchanged and uncontradicted. They govern how *Grid Nodes* get and rotate their secrets (per-Node `kv-hd-{service}-{env}`, Managed Identity, rotation SLAs, Event Grid propagation, audit). The reveal surface neither provisions, rotates, nor consumes those secrets on a Node's behalf. It is operator inspection sitting beside that machinery, not inside it.

Relationship to ADR-0094: the Connectors Framework establishes the opt-in, read-only, no-host-side-secrets posture for HoneyHub's "view everything" surface (reuse the operator's own `gh`/`az` sign-ins). Reveal is the narrowest, most sensitive case of that same posture (a single secret value rather than a count or a dashboard), and inherits ADR-0094's read-through, no-host-side-storage stance. The destructive-verb confirmation-gate precedent in ADR-0094 D5 (Service Bus) is the sibling pattern: a deliberately scoped, explicitly-gated exception to a read-only ceiling, recorded rather than hidden.

### D3. No-log / no-sync guarantees (invariant 8 compliance)

The revealed value MUST NOT be written to any durable or observable channel. Specifically:

- **Never logged.** The bridge's transport type that carries the value (`SecretReveal`) has a hand-written redacting `Debug` implementation, so `{:?}` formatting renders `<redacted>` rather than the value. Any accidental `tracing` / `log` / panic-format of the carrying struct emits the placeholder, never the secret. This is the bridge-side enforcement of invariant 8.
- **Never persisted to disk.** The value is not written to any file, database, cache, or run record. It does not appear in `DispatchSession` / `DispatchRun` / `DispatchMessage` transcripts (ADR-0090 D8: "no secret values streamed into HoneyHub transcripts"; ADR-0092 retention).
- **Never written to `localStorage` / IndexedDB / any web persistence.** The cockpit holds it only in volatile component memory (see D4).
- **Never synced anywhere.** It is not aggregated, not sent to notifications (ADR-0090 D7 state-only notifications already forbid this), not relayed off-host. It rides the local bridge WebSocket on demand only, in response to an explicit reveal request, and exists only for the lifetime of that view.

This keeps the surface compliant with invariant 8 (secret values never appear in logs, traces, exceptions, or telemetry) and consistent with invariant 282's complement (no operator-event channel carries secret values).

### D4. Persistence and lifetime rules

The revealed plaintext lives only in volatile React component state on the cockpit, never in any store. It is:

- rendered only on secret-kind rows (D1 limits the surface to secrets);
- cleared on **Hide** (the explicit inverse action);
- cleared on **vault collapse**;
- cleared on **vault switch**;
- cleared on **any vault-list reload** (subscription change or refresh).

A stale or out-of-order reveal response is dropped via a pending-reveal key: only the response that matches the currently-awaited reveal is rendered, so a late reply for a since-changed selection cannot paint a value onto the wrong row.

The intended lifetime is "visible while the operator is actively looking at this one secret on this one vault, and gone the moment they navigate away." There is no persistence across reloads, sessions, or devices.

### D5. Boundary and input validation

- **Data-plane access** is via `az keyvault secret show` run under the operator's own host `az` session on the bridge host. HoneyHub shells the operator's existing sign-in (ADR-0094 no-host-side-secrets); it holds no Azure credential of its own for this path.
- **Argument safety.** Vault name, subscription, and secret name are shape-validated before they ride `argv` into the `az` invocation, so cockpit-supplied identifiers cannot smuggle additional arguments or shell metacharacters into the data-plane call.
- **Kind restriction.** Only secret-kind entries expose Reveal. Keys and certificates are out of scope and must not gain a plaintext / private-material reveal under this ADR; widening to other kinds would require a new decision.

### D6. Audit expectations

HoneyHub v1 is a single-operator, local-first cockpit with no hosted backend (ADR-0091) and no central audit substrate wired into the bridge. Consistent with the rest of HoneyHub's local model:

- There is **no server-side audit** of reveal actions in v1, because there is no server. This is the deliberate, accepted posture, not an oversight. The Grid's durable audit substrate (invariant 47, `IAuditLog`, ADR-0030) governs Grid *services*; the local cockpit is not one.
- The **authoritative audit of the underlying data-plane read already exists in Azure**: every `az keyvault secret show` is a Key Vault data-plane access subject to that vault's diagnostic settings and Log Analytics routing (invariant 22, ADR-0006 Tier 4). The reveal therefore inherits Azure-side audit of who read which secret and when, at the only layer where a tamper-resistant record belongs.
- If HoneyHub later grows a multi-operator or hosted tier, a reveal-action audit trail becomes a prerequisite of that tier and must be decided then. v1 single-operator local does not carry it.

---

## Consequences

### Positive

- The shipped operator-directed reveal capability has an explicit decision of record, so the next Grid Review pass sees a sanctioned carve-out instead of an unexplained secret-plaintext surface, and the merge is no longer a bare override.
- The boundary is written down: secrets-only, read-through, no-store, no-log, no-sync, volatile-only, validated argv, Azure-side audit. Future HoneyHub work (and future reviewers) inherit the same standard rather than re-litigating it.
- Invariants 8 and 9 are clarified at their edges (what invariant 9 does and does not cover; how invariant 8 is enforced on the bridge) without being weakened.

### Negative / accepted risk

- A plaintext secret value is, by construction, on screen during reveal. Anyone with eyes on the operator's unlocked cockpit at that moment can read it. This is identical to the operator running `az keyvault secret show` in their own terminal and is accepted as inherent to a self-service inspection tool.
- No server-side audit of reveal actions in v1 (D6). Mitigated by Azure-side data-plane audit, but the cockpit-level "operator clicked Reveal" event is not independently recorded.
- The carve-out is HoneyHub-local and must not be cited as precedent for any Grid *Node* reading secret plaintext outside `ISecretStore`. Invariant 9 stands for Nodes.

### Affected Nodes

- **HoneyDrunk.HoneyHub** owns the capability and the guarantees in D3 to D5 (`SecretReveal` redacting `Debug`, volatile-only cockpit state, argv shape-validation, secret-kind restriction). No other Node changes.
- No catalog edit. No new invariant (ADR-0089 / ADR-0091 / ADR-0092 precedent: HoneyHub ADRs add governance, not invariants, at v1). This ADR instead clarifies the scope of existing invariants 8 and 9 at their HoneyHub edge.

### Migration

None. This documents an already-shipped surface and binds it to the stated boundary.

---

## Alternatives Considered

### Revert the reveal feature

Rejected by the operator. The feature is operator-directed (the operator explicitly asked to view Key Vault secrets from the cockpit), it exposes nothing the operator cannot already read via `az`, and it lives entirely inside the local-first boundary. The cost of reverting an operator-requested, low-incremental-risk inspection tool is not warranted; documenting the carve-out is the proportionate response.

### Route reveal through `ISecretStore`

Rejected as a category error. `ISecretStore` is the brokered path for Grid Nodes to consume secrets programmatically at runtime. A human inspecting their own vault entry is not a Node consuming a secret, and forcing the read through `ISecretStore` would (a) misrepresent what is happening, (b) require HoneyHub to hold or broker Azure credentials it deliberately does not hold (ADR-0094 no-host-side-secrets), and (c) add a fake abstraction over what is really just the operator's own `az` session.

### Mask-only (show length / last-4, never full plaintext)

Rejected for this surface. The operator's stated need is to actually read the value (for example, to copy a connection string or compare a rotated key). A permanent mask defeats the operator-directed purpose. The chosen design instead makes full plaintext available only on explicit per-secret action, volatile-only, and immediately clearable, which bounds exposure without crippling the use case.

### Defer until a hosted / multi-operator tier exists with full audit

Rejected. Gating a single-operator local inspection tool behind a hosted-tier audit substrate that does not exist yet would block an operator-requested capability indefinitely for a risk (no cockpit-level audit) that is already mitigated by Azure-side data-plane audit (D6). The hosted-tier audit requirement is recorded as a prerequisite of *that* tier, not of v1.

---

## Open Questions

| Question | Owner | Status |
|---|---|---|
| Does a future hosted / multi-operator HoneyHub tier require a cockpit-level reveal-action audit trail (operator + secret + timestamp)? | Architecture / Security | Open (gated on that tier; v1 relies on Azure-side data-plane audit) |
| Should Reveal ever be extended to certificate public parts or key metadata (never private material)? | Architecture / Product | Open (out of scope here; would need a new decision) |
