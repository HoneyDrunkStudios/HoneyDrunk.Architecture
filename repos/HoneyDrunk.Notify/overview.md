# HoneyDrunk.Notify — Overview

**Sector:** Ops  
**Version:** 0.1.0  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Notify`

## Purpose

Channel-agnostic notification dispatching with multi-provider support. Email (SMTP, Resend) and SMS (Twilio) with queue-backed async dispatch.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Notify.Abstractions` | Abstractions | Notification channel contracts |
| `HoneyDrunk.Notify` | Runtime | Dispatch engine |
| `HoneyDrunk.Notify.Hosting.AspNetCore` | Hosting | ASP.NET Core integration |
| `HoneyDrunk.Notify.Providers.Email.Smtp` | Provider | SMTP email |
| `HoneyDrunk.Notify.Providers.Email.Resend` | Provider | Resend email |
| `HoneyDrunk.Notify.Providers.Sms.Twilio` | Provider | Twilio SMS |
| `HoneyDrunk.Notify.Queue.AzureStorage` | Provider | Azure Storage queue |
| `HoneyDrunk.Notify.Queue.InMemory` | Testing | In-memory queue |
