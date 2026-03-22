# HoneyDrunk.Web.Rest — Boundaries

## What Web.Rest Owns
- Response envelope contracts (`ApiResult<T>`, `ApiErrorResponse`)
- Correlation propagation (`X-Correlation-Id` header)
- Exception-to-HTTP-status mapping
- Model validation with `ValidationError` collections
- Pagination contracts (`PageRequest`, `PageResult<T>`)
- JSON conventions (camelCase, enum-as-string, null-omission)
- Request logging scopes and telemetry tags

## What Web.Rest Does NOT Own
- **Authentication middleware** — Belongs in Auth.AspNetCore
- **Business logic** — Controllers/endpoints contain domain logic
- **Transport messaging** — Belongs in Transport
- **Data access** — Belongs in Data
