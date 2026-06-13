# Dispatch Plan — Kernel Adoption Alignment

## Summary
Coordinate per-repo fixes from the Kernel adoption audit so every active .NET Node consumes Kernel identity/context correctly, avoids unnecessary runtime dependencies, and updates Architecture compatibility metadata after implementation reality changes.

## Trigger
2026-05-17 Kernel adoption audit found drift: missing Grid/Operation context at some entry points, direct queue secret/config reads in Notify, runtime Kernel dependency where Abstractions should suffice, and stale compatibility/version metadata.

## Classification
- Request type: `cross-repo-change` / `dependency-upgrade`
- Tier: 2
- Initiative: `kernel-adoption-alignment`
- Actor: Agent for all packets; Notify has one deploy-time human prerequisite for runtime setting confirmation if the Functions binding still requires it.

## Wave Diagram

### Wave 1 — Kernel foundation
- [ ] `01-kernel-context-bootstrap-and-well-known-node-ids.md` — establish canonical identity/context seams.

### Wave 2 — Upstream Core dependency cleanup
- [ ] `02-transport-drop-kernel-runtime-dependency.md`
  - Blocked by: packet 01.

### Wave 3 — Per-repo consumers, parallel after prerequisites
- [ ] `03-vault-align-kernel-version.md` — blocked by packet 01.
- [ ] `04-auth-align-kernel-version.md` — blocked by packets 01, 03.
- [ ] `05-web-rest-require-kernel-request-context.md` — blocked by packet 01.
- [ ] `06-data-require-context-for-outbox-enrichment.md` — blocked by packets 01, 02.
- [ ] `07-vault-rotation-establish-timer-operation-context.md` — blocked by packets 01, 03.
- [ ] `08-notify-align-identity-and-queue-secret-boundary.md` — blocked by packets 01, 03.
- [ ] `09-pulse-align-kernel-identity-and-version.md` — blocked by packets 01, 02.
- [ ] `10-communications-drop-kernel-runtime-dependency.md` — blocked by packet 01.

### Wave 4 — Architecture truth reconciliation
- [ ] `11-architecture-reconcile-kernel-adoption-catalogs.md` — blocked by packets 01-10.

## Packet Links
- [01 — HoneyDrunk.Kernel: Kernel context bootstrap + well-known Node IDs](01-kernel-context-bootstrap-and-well-known-node-ids.md)
- [02 — HoneyDrunk.Transport: Drop full Kernel runtime dependency](02-transport-drop-kernel-runtime-dependency.md)
- [03 — HoneyDrunk.Vault: Align Kernel package version](03-vault-align-kernel-version.md)
- [04 — HoneyDrunk.Auth: Align Kernel package version](04-auth-align-kernel-version.md)
- [05 — HoneyDrunk.Web.Rest: Require Kernel context in HTTP pipeline](05-web-rest-require-kernel-request-context.md)
- [06 — HoneyDrunk.Data: Require context for outbox enrichment](06-data-require-context-for-outbox-enrichment.md)
- [07 — HoneyDrunk.Vault.Rotation: Establish timer operation context](07-vault-rotation-establish-timer-operation-context.md)
- [08 — HoneyDrunk.Notify: Align identity and queue secret boundary](08-notify-align-identity-and-queue-secret-boundary.md)
- [09 — HoneyDrunk.Pulse: Align canonical Pulse identity](09-pulse-align-kernel-identity-and-version.md)
- [10 — HoneyDrunk.Communications: Drop unnecessary Kernel runtime dependency](10-communications-drop-kernel-runtime-dependency.md)
- [11 — HoneyDrunk.Architecture: Reconcile catalogs/compatibility](11-architecture-reconcile-kernel-adoption-catalogs.md)

## Site Sync Flag
No immediate Studios website packet is required unless Architecture reconciliation changes public Node versions/signals surfaced on the website. If packet 11 updates public-facing catalog data consumed by Studios, run `site-sync` afterward.

## Rollback Plan
- Kernel packet 01 is the dependency root. If it fails, do not start packets 02-10.
- Downstream packets should be separate PRs. Revert a failing downstream PR independently without reverting Kernel unless the shared seam is proven defective.
- Architecture packet 11 should land last and reflect only merged repo reality; if downstream work is partially complete, record partial compatibility instead of claiming full alignment.

## Filing Commands

```bash
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel --title "Kernel context bootstrap + well-known Node IDs" --body-file "generated/work-items/active/kernel-adoption-alignment/01-kernel-context-bootstrap-and-well-known-node-ids.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Transport --title "Drop full Kernel runtime dependency" --body-file "generated/work-items/active/kernel-adoption-alignment/02-transport-drop-kernel-runtime-dependency.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault --title "Align Kernel package version" --body-file "generated/work-items/active/kernel-adoption-alignment/03-vault-align-kernel-version.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Auth --title "Align Kernel package version" --body-file "generated/work-items/active/kernel-adoption-alignment/04-auth-align-kernel-version.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Web.Rest --title "Require Kernel context in HTTP pipeline" --body-file "generated/work-items/active/kernel-adoption-alignment/05-web-rest-require-kernel-request-context.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Data --title "Require context for outbox enrichment" --body-file "generated/work-items/active/kernel-adoption-alignment/06-data-require-context-for-outbox-enrichment.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault.Rotation --title "Establish timer operation context" --body-file "generated/work-items/active/kernel-adoption-alignment/07-vault-rotation-establish-timer-operation-context.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Notify --title "Align identity and queue secret boundary" --body-file "generated/work-items/active/kernel-adoption-alignment/08-notify-align-identity-and-queue-secret-boundary.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Pulse --title "Align canonical Pulse identity" --body-file "generated/work-items/active/kernel-adoption-alignment/09-pulse-align-kernel-identity-and-version.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Communications --title "Drop unnecessary Kernel runtime dependency" --body-file "generated/work-items/active/kernel-adoption-alignment/10-communications-drop-kernel-runtime-dependency.md" --label "kernel-adoption,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Reconcile catalogs/compatibility" --body-file "generated/work-items/active/kernel-adoption-alignment/11-architecture-reconcile-kernel-adoption-catalogs.md" --label "kernel-adoption,tier-2"
```

## Blocking Relationships
The `dependencies:` frontmatter in each packet is canonical. After filing, wire GitHub blocked-by relationships for every dependency entry using `addBlockedBy`.
