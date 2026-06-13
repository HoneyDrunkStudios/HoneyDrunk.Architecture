# HoneyDrunk.NovOutbox Invariants

- Every accepted customer API call resolves to a tenant and project before it can enqueue or delegate message work.
- API-key secrets are one-time visible and stored only as verifiable secret material or secret handles.
- Tenant tier and rate-limit checks run before message work enters Communications.
- Billing events describe product usage; payment-provider concerns stay behind billing adapters.
- Communications owns send/suppress/schedule decisions. NovOutbox owns product access, limits, and customer visibility.
- Notify owns delivery mechanics. NovOutbox does not directly own SMTP, SMS, provider queues, or retry mechanics except for explicit diagnostics and smoke paths.
- Public marketing content must not depend on private application internals.
- Aspire is local-development orchestration only; production deployment remains Azure Container Apps.
- The private repo must prove reusable workflow access, secrets, token permissions, package publishing, and review automation before being treated as a normal Grid repo.
