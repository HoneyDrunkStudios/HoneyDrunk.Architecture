# Vendor Inventory

External vendors, services, and third-party dependencies across the HoneyDrunk Grid.

**Last Updated:** 2026-06-07

> **Related:** this file is the **product-level** vendor inventory ("which SaaS products do we use"). The **artifact-level** index ("which credentials, identifiers, and identity bindings do we hold against each vendor, plus everything else load-bearing") lives in [`sensitive-inventory.md`](./sensitive-inventory.md) per ADR-0083. For any vendor below whose credentials the Grid holds — SonarCloud (`SONAR_TOKEN`), NuGet.org (`NUGET_API_KEY`), GitHub (PATs / App keys), Azure (tenant/subscription IDs, OIDC, Key Vault), Anthropic / OpenAI (API keys) — see that file for the rotation posture and expiration tracking.

---

## Cloud Platform

| Vendor | Product | Used By | Tier |
|--------|---------|---------|------|
| Microsoft Azure | App Service (container hosting) | Pulse.Collector | Paid |
| Microsoft Azure | Functions (serverless) | Notify.Functions | Consumption plan |
| Microsoft Azure | Key Vault | Vault provider, Notify, Pulse | Per-operation |
| Microsoft Azure | Service Bus | Transport.AzureServiceBus | Paid |
| Microsoft Azure | Storage Queues | Transport.StorageQueue, Notify | Free tier available |
| Microsoft Azure | Storage Blobs | Notify | Free tier available |
| Microsoft Azure | Monitor / Application Insights | Pulse (OTel exporter) | Free ingestion tier |
| Microsoft Azure | Container Registry (ACR) | Pulse (optional, can override GHCR) | Paid |
| Microsoft Azure | Entra ID (Azure AD) | OIDC auth for deployments | Included with subscription |
| AWS | Secrets Manager | Vault.Providers.Aws | Per-secret |

---

## AI / Developer Tools

| Vendor | Product | Used By | Tier |
|--------|---------|---------|------|
| GitHub | Copilot | All repos (agentic development, code review, architecture agents) | Business |
| OpenAI | API (GPT models) | Agent workflows, future Agent Kit Node | Paid (usage-based) |

---

## Domain Registrar, DNS, and Edge

| Vendor | Product | Purpose | Tier |
|--------|---------|---------|------|
| Cloudflare | Registrar, authoritative DNS, CDN, DDoS protection, WAF | Domain registration, DNS management, edge caching, security | Free tier (registrar at-cost; Pro if a future Node justifies it) |

> Per ADR-0029, Cloudflare is the Grid's registrar, authoritative DNS, and edge platform of choice. All three Grid-owned domains (`honeydrunkstudios.com`, `tatteddev.com`, `honeyhub.app` — see [`owned-domains.md`](./owned-domains.md)) are at Cloudflare Registrar as of 2026-06-07. GoDaddy is no longer a Grid vendor.

---

## Hosting

| Vendor | Product | Used By | Tier |
|--------|---------|---------|------|
| Vercel | Static site hosting + auto-deploy | Studios website | Free (hobby) / Pro |
| GitHub | Container Registry (GHCR) | Pulse.Collector, Notify.Worker images | Free (public) |
| Microsoft | Container Registry (MCR) | Base .NET images (`mcr.microsoft.com/dotnet/*`) | Free |

---

## Source Control / CI/CD

| Vendor | Product | Used By | Tier |
|--------|---------|---------|------|
| GitHub | Git hosting, Actions, Releases, Environments | All repos | Free / Team |
| GitHub | Code Scanning (SARIF) | All repos via Actions | Free (public repos) |

### Third-Party GitHub Actions

| Action | Author | Purpose |
|--------|--------|---------|
| `softprops/action-gh-release@v2` | softprops | GitHub Release creation |
| `azure/login@v2` | Microsoft | Azure OIDC/SP authentication |
| `azure/functions-action@v2` | Microsoft | Azure Functions deployment |
| `azure/webapps-deploy@v3` | Microsoft | App Service deployment |
| `docker/login-action@v3` | Docker | Container registry login |
| `gitleaks/gitleaks-action@v2` | Gitleaks | Secret scanning |
| `aquasecurity/trivy-action@0.35.0` | Aqua Security | Container + IaC vulnerability scanning |
| `github/codeql-action@v3` | GitHub | SAST analysis |
| `anchore/sbom-action@v0` | Anchore | SBOM generation (SPDX) |
| `EnricoMi/publish-unit-test-result-action@v2` | EnricoMi | Test result reporting |
| `peter-evans/find-comment@v3` | Peter Evans | PR comment management |
| `peter-evans/create-or-update-comment@v4` | Peter Evans | PR comment management |

---

## Notification Providers (SaaS)

| Vendor | Product | Used By | Tier |
|--------|---------|---------|------|
| Resend | Transactional email API | Notify.Providers.Email.Resend | Free tier / Paid |
| Twilio | SMS messaging | Notify.Providers.Sms.Twilio | Pay-per-use |

---

## Observability / Analytics (SaaS)

| Vendor | Product | Used By | Tier |
|--------|---------|---------|------|
| Sentry | Error tracking | Pulse (Sink.Sentry) | Free tier / Paid |
| PostHog | Product analytics | Pulse (Sink.PostHog) | Free tier / Paid |
| Grafana Labs | Loki (logs), Tempo (traces), Mimir (metrics) | Pulse sinks | Self-hosted / Cloud |
| CNCF | OpenTelemetry (framework + OTLP) | Kernel, Pulse, Auth, Data, Transport, Web.Rest | Open-source |

---

## Package Registries

| Vendor | Product | Used By | Tier |
|--------|---------|---------|------|
| NuGet.org | .NET package registry | All Node packages | Free |
| npm | JavaScript package registry | Studios website | Free |

---

## Database

| Vendor | Product | Used By | Tier |
|--------|---------|---------|------|
| Microsoft | SQL Server (EF Core provider) | Data.SqlServer | Paid (Azure SQL) / Free (Express) |

---

## Security Scanning (Open-Source)

| Vendor | Product | Purpose | Tier |
|--------|---------|---------|------|
| Gitleaks | Secret scanning | Diff + full-repo scan | Open-source |
| GitHub | CodeQL | SAST / code scanning | Free (public repos) |
| Aqua Security | Trivy | Container + IaC vulnerability scanning | Open-source |
| Anchore | Syft | SBOM generation (SPDX) | Open-source |

---

## Accessibility / Performance (Open-Source)

| Vendor | Product | Purpose | Tier |
|--------|---------|---------|------|
| pa11y | Accessibility scanner | WCAG compliance | Open-source |
| Deque Systems | axe-core | Accessibility engine | Open-source |
| Google | Lighthouse | Performance benchmarking (target: >= 95) | Free |

---

## Vendor Lock-In Assessment

| Risk Level | Area | Detail |
|------------|------|--------|
| **High** | Azure | 10 services in use. Mitigated partially by Vault/Transport provider-slot pattern (swap implementations without changing consumers). |
| **Medium** | Cloudflare | Registrar + authoritative DNS + edge for every Grid-owned domain (consolidated per ADR-0029). Single point of compromise for external-surface integrity. Mitigations: hardware-key-backed 2FA on the account (mandatory per ADR-0029 — **currently TOTP; hardware key pending**, tracked as a follow-up in the implementation notes), Registrar-level transfer lock per zone, per-zone API tokens scoped narrowly (D5). Reversibility: domain transfer-out and zone export are mechanically supported by Cloudflare — the exit door stays open. |
| **Medium** | GitHub | Source control + CI/CD + container registry + code scanning. Migration would require workflow rewrites. |
| **Medium** | Vercel | Website hosting. Next.js is portable; Vercel-specific features (edge functions, analytics) not heavily used. |
| **Low** | Resend / Twilio | Notification providers behind `INotificationProvider` abstraction. Swappable. |
| **Low** | Sentry / PostHog | Behind Pulse sink abstractions. Swappable. |
| **None** | OpenTelemetry | CNCF standard. Vendor-neutral by design. |

---

## How to Update This File

- **New vendor adopted:** Add to the appropriate section with product, consuming repos, and tier.
- **Vendor removed:** Remove the row.
- **Tier change:** Update the Tier column.
- **Lock-in concern:** Update the assessment table.
