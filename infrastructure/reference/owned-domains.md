# Owned Domains

HoneyDrunk-controlled domain inventory for DNS, registrar, tunnel, and public-surface planning.

**Last Updated:** 2026-06-01

---

| Domain | Intended Use | Current Notes |
|--------|--------------|---------------|
| `honeydrunkstudios.com` | Primary HoneyDrunk Studios public/studio domain; preferred parent for Grid and product subdomains. | ADR-0088 retired the former ADR-0044 `grid-review.honeydrunkstudios.com` Cloudflare Tunnel endpoint. No inbound Grid Review tunnel is active; ADR-0086 owns review execution through the pull-based local worker. |
| `honeyhub.app` | HoneyHub product/application domain. | Reserve for HoneyHub-facing product surfaces; avoid using for internal Grid review plumbing. |
| `tatteddev.com` | Personal/developer domain. | Keep separate from HoneyDrunk Studios production surfaces unless explicitly needed. |

---

## Operational Guidance

- Prefer `honeydrunkstudios.com` for HoneyDrunk Studios infrastructure and product subdomains unless a product-specific domain is explicitly more appropriate.
- Use `honeyhub.app` for HoneyHub-branded application surfaces, not shared Grid infrastructure.
- Treat `tatteddev.com` as personal/developer scope and avoid coupling it to HoneyDrunk production infrastructure.
- Keep Cloudflare as the authoritative DNS/edge target per ADR-0029 and `vendor-inventory.md`.

## Retired ADR-0044 Webhook Candidate

`grid-review.honeydrunkstudios.com` was the candidate Cloudflare Tunnel hostname for the ADR-0044 signed-webhook review path. ADR-0086 replaced that path with the pull-based local worker, and ADR-0088 removed the OpenClaw-bound tunnel on 2026-06-01.

Do not recreate this hostname for Grid Review without a new ADR that explicitly reverses ADR-0086/ADR-0088.
