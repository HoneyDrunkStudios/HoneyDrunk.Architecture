# HoneyDrunk.Auth — Boundaries

## What Auth Owns
- JWT Bearer token validation (industry-standard)
- Policy-based authorization (scope/role/ownership-based)
- Vault-backed signing key management with caching
- ASP.NET Core middleware integration
- Fail-fast startup validation

## What Auth Does NOT Own
- **User management** — No user CRUD, registration, or profiles
- **Token issuance** — Auth validates tokens, does not create them
- **Identity provider** — No OAuth server, no login flows
- **Session management** — No session store or refresh tokens
- **Secret storage** — Uses Vault for signing keys, does not store secrets itself
