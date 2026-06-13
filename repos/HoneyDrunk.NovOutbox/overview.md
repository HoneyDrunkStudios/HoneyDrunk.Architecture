# HoneyDrunk.NovOutbox Overview

NovOutbox is the customer-facing commercial product that supersedes the earlier Notify Cloud planning name.

The private `HoneyDrunk.NovOutbox` repository owns the hosted notification API and customer console. It turns HoneyDrunk's internal Communications and Notify capabilities into a product boundary customers can use: signup, projects, API keys, tenant tiers, rate limits, usage logs, and billing state.

The public marketing/docs website is a separate public repository. That repo may explain the product, publish docs, and support acquisition, but it must not contain the private application code, operational wiring, billing implementation, or tenant-management surface.

## Core shape

- Product name: NovOutbox.
- Private technical repo/package family: `HoneyDrunk.NovOutbox`.
- Historical placeholder: `HoneyDrunk.Notify.Cloud`; do not use for new repo, package, or customer-facing naming.
- Runtime path: customer request -> API-key tenant resolution -> tenant tier/rate-limit checks -> Communications orchestration -> Notify delivery -> usage/log/billing emission.
- Local dev: Aspire AppHost only.
- Production: Azure Container Apps through curated HoneyDrunk infrastructure and Actions workflows.
