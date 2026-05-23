# HoneyDrunk.Studios — Integration Points

## Build-Time Inputs

| Source | Path | Usage |
|--------|------|-------|
| **HoneyDrunkStudios/HoneyDrunk.Architecture** | `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/services.json`, `catalogs/contracts.json`, `catalogs/grid-health.json` | Node, Sector, signal, and relationship data for the `/grid` visualization and the `/nodes` browser. |
| **HoneyDrunkStudios/HoneyDrunk.Architecture** | `adrs/`, `pdrs/`, `business/decisions/` | Public decision-record browsers (`/adrs`, `/pdrs`). |
| **HoneyDrunkStudios/HoneyDrunk.Architecture** | `initiatives/roadmap.md`, `initiatives/releases.md` | Public roadmap and release surfaces. |
| **HoneyDrunkStudios/HoneyDrunk.Web.UI** (future per [ADR-0071](../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md)) | `@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react` | Design tokens, primitive CSS, and React component implementations consumed at build time as npm packages. |

## Runtime Inputs

Studios is static-first; production builds are pre-rendered and served from edge. Runtime dependencies are minimal:

| Surface | Runtime concern |
|---------|-----------------|
| **Cloudflare** (per [ADR-0029](../../adrs/ADR-0029-cloudflare-dns-and-edge-platform.md)) | DNS, edge cache, TLS, DDoS protection. |
| **Newsletter / contact form (if any)** | Routes through [HoneyDrunk.Notify](../../adrs/ADR-0019-honeydrunk-communications-boundary-refactor.md) for outbound email. |

## What Studios Does NOT Integrate With

- **Grid runtime contracts** — `IAuditLog`, `IGridContext`, `ISecretStore`, etc. Studios does not call them.
- **HoneyDrunk.Notify.Cloud tenant APIs** — Studios may link to the Notify Cloud product surface, but does not call its tenant-management API.
- **AI providers** — Studios runs no agents at request time.
- **Database backings** — Studios is static-first; no relational store of its own.

## Outbound (telemetry only)

| Sink | Direction | Notes |
|------|-----------|-------|
| **HoneyDrunk.Pulse** (future / per the per-PDR analytics ADR) | Emit only | Page-level analytics (per the future product-analytics ADR — `HoneyDrunk.Signal`). One-way; no runtime dependency on Pulse. |
