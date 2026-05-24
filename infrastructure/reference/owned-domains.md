# Owned Domains

HoneyDrunk-controlled domain inventory for DNS, registrar, tunnel, and public-surface planning.

**Last Updated:** 2026-05-24

---

| Domain | Intended Use | Current Notes |
|--------|--------------|---------------|
| `honeydrunkstudios.com` | Primary HoneyDrunk Studios public/studio domain; preferred parent for Grid and product subdomains. | Candidate parent for ADR-0044 Grid Review webhook, e.g. `grid-review.honeydrunkstudios.com`. |
| `honeyhub.app` | HoneyHub product/application domain. | Reserve for HoneyHub-facing product surfaces; avoid using for internal Grid review plumbing. |
| `tatteddev.com` | Personal/developer domain. | Keep separate from HoneyDrunk Studios production surfaces unless explicitly needed. |

---

## Operational Guidance

- Prefer `honeydrunkstudios.com` for HoneyDrunk Studios infrastructure and product subdomains unless a product-specific domain is explicitly more appropriate.
- Use `honeyhub.app` for HoneyHub-branded application surfaces, not shared Grid infrastructure.
- Treat `tatteddev.com` as personal/developer scope and avoid coupling it to HoneyDrunk production infrastructure.
- Keep Cloudflare as the authoritative DNS/edge target per ADR-0029 and `vendor-inventory.md`.

## ADR-0044 Webhook Candidate

Use `grid-review.honeydrunkstudios.com` for the Cloudflare Tunnel endpoint unless Cloudflare zone state or ownership constraints require a different HoneyDrunk-owned domain.
