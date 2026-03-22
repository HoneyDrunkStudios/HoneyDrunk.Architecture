# HoneyDrunk.Notify — Boundaries

## What Notify Owns
- Channel-agnostic notification interfaces
- Email providers (SMTP, Resend)
- SMS providers (Twilio)
- Template rendering
- Queue-backed async dispatch (Azure Storage, InMemory)
- Background notification worker

## What Notify Does NOT Own
- **User preferences** — Applications manage notification preferences
- **Transport messaging** — Notify uses its own queue system, not Transport
- **Push notifications** — Not yet supported (future provider slot)
