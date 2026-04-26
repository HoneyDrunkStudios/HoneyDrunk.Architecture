# Azure Provisioning Guide

Step-by-step runbook for provisioning Azure resources for a new HoneyDrunk Grid service. All steps use the Azure Portal and GitHub UI.

**Last Updated:** 2026-04-25

---

## Prerequisites

- Access to the Azure Portal with Owner or Contributor role on the target subscription
- Admin access to the HoneyDrunkStudios GitHub organization (for environment variables)

---

## Overview

Provisioning a new service:

1. Create the Resource Group
2. Create Azure resources (Function App, Container App, Storage, etc.)
3. Create the Key Vault and populate secrets
4. Create the App Registration with OIDC federated credentials
5. Assign RBAC roles
6. Configure GitHub Environment variables
7. Test the deployment

Use [azure-naming-conventions.md](azure-naming-conventions.md) for all resource names.

> **Containerized Nodes:** Per ADR-0015, every containerized deployable Node runs on **Azure Container Apps**, not App Service. Provisioning relies on the shared Container Registry (`acrhdshared{env}`) and Container Apps Environment (`cae-hd-{env}`) in `rg-hd-platform-{env}`. Stand those up once per environment via the dedicated walkthroughs before standing up any per-Node Container App.

---

## Step 1: Create Resource Group

1. Go to **Azure Portal** -> **Resource groups** -> **Create**
2. Select the correct **Subscription** (e.g., `honeydrunk-dev`)
3. **Resource group name:** `rg-hd-{service}-{env}` (e.g., `rg-hd-notify-dev`)
4. **Region:** East US (or your preferred region)
5. Click **Review + create** -> **Create**

---

## Step 2: Create Resources

### Option A: Azure Function App (e.g., Notify)

#### 2a. Storage Account

1. Go to **Storage accounts** -> **Create**
2. **Subscription:** same as above
3. **Resource group:** `rg-hd-notify-dev`
4. **Storage account name:** `sthdnotifydev` (no hyphens — Azure doesn't allow them)
5. **Region:** East US
6. **Performance:** Standard
7. **Redundancy:** LRS (Locally-redundant)
8. Click **Review + create** -> **Create**

#### 2b. Function App

1. Go to **Function App** -> **Create**
2. **Subscription / Resource group:** same as above
3. **Function App name:** `func-hd-notify-dev`
4. **Runtime stack:** .NET (Isolated)
5. **Version:** 10
6. **Region:** East US
7. **Operating System:** Linux
8. **Hosting plan:** Consumption (Serverless)
9. On the **Storage** tab, select the storage account you just created (`sthdnotifydev`)
10. Click **Review + create** -> **Create**

### Option B: Container App (e.g., Pulse, Notify.Worker)

Per ADR-0015, containerized Nodes run on **Azure Container Apps** with a shared Container Apps Environment and Container Registry per environment.

#### 2a. Provision shared platform resources (once per environment)

Both of these live in `rg-hd-platform-{env}` and serve every containerized Node in the environment. Skip to **2b** if they already exist.

1. Container Registry — follow [Container Registry creation](container-registry-creation.md) to provision `acrhdshared{env}` (Basic SKU).
2. Container Apps Environment — follow [Container Apps Environment creation](container-apps-environment-creation.md) to provision `cae-hd-{env}` (Consumption-only, logs to `log-hd-shared-{env}`).

#### 2b. Container App

Follow [Container App creation](container-app-creation.md) to provision `ca-hd-{service}-{env}` in `rg-hd-{service}-{env}`, attached to the shared `cae-hd-{env}` and pulling from `acrhdshared{env}`. Key choices baked into the walkthrough:

- System-assigned Managed Identity with `AcrPull` on the shared ACR and `Key Vault Secrets User` on the Node's vault (Step 5 of this guide can be skipped for Container Apps — RBAC is wired in the walkthrough).
- Ingress enabled (HTTP/2 for gRPC like Pulse.Collector; disabled for queue-driven workers like Notify.Worker).
- Revision mode **Multiple** with traffic splitting on deploy (Invariant 36).
- Bootstrap env vars (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID`) seeded at create time.

---

## Step 3: Create Key Vault and Populate Secrets

### 3a. Create the Key Vault

1. Go to **Key vaults** -> **Create**
2. **Subscription / Resource group:** same as the service
3. **Key vault name:** `kv-hd-{service}-{env}` (e.g., `kv-hd-notify-dev`)
4. **Region:** East US
5. **Pricing tier:** Standard
6. On the **Access configuration** tab:
   - Select **Azure role-based access control** (not Vault access policy)
7. Click **Review + create** -> **Create**

### 3b. Grant Yourself Access

Before you can add secrets, you need the Key Vault Secrets Officer role on the vault:

1. Open the Key Vault you just created
2. Go to **Access control (IAM)** -> **Add role assignment**
3. **Role:** Key Vault Secrets Officer
4. **Assign access to:** User, group, or service principal
5. **Members:** select your own account
6. Click **Review + assign**

### 3c. Add Secrets

1. In the Key Vault, go to **Secrets** -> **Generate/Import**
2. Add each secret. Example for Notify:

| Name | Value | Where to get it |
|------|-------|-----------------|
| `NotifyQueueConnection` | Storage account connection string | Storage account -> **Access keys** -> **Connection string** |
| `Resend--ApiKey` | Resend API key | resend.com dashboard |
| `Twilio--AccountSid` | Twilio Account SID | twilio.com console |
| `Twilio--AuthToken` | Twilio Auth Token | twilio.com console |

See [azure-identity-and-secrets.md](azure-identity-and-secrets.md) for secret naming rules and the full list per service.

---

## Step 4: Create App Registration with OIDC

### 4a. Create the App Registration

1. Go to **Microsoft Entra ID** -> **App registrations** -> **New registration**
2. **Name:** `sp-hd-{service}-{env}` (e.g., `sp-hd-notify-dev`)
3. **Supported account types:** Accounts in this organizational directory only
4. Click **Register**
5. On the overview page, copy the **Application (client) ID** — you'll need this for GitHub and RBAC

### 4b. Add the Federated Credential

1. In the App Registration, go to **Certificates & secrets** -> **Federated credentials** -> **Add credential**
2. **Federated credential scenario:** GitHub Actions deploying Azure resources
3. Fill in:

| Field | Value |
|-------|-------|
| Organization | `HoneyDrunkStudios` |
| Repository | `HoneyDrunk.Notify` (or the relevant repo) |
| Entity type | Environment |
| GitHub environment name | `development` |
| Name | `github-development` |

4. Click **Add**

Repeat for each environment (`staging`, `production`) when needed.

---

## Step 5: Assign RBAC Roles

The App Registration needs two roles: one on the resource group and one on the Key Vault.

### 5a. Contributor on the Resource Group

1. Go to the **Resource group** (e.g., `rg-hd-notify-dev`)
2. Go to **Access control (IAM)** -> **Add role assignment**
3. **Role:** Contributor
4. **Assign access to:** User, group, or service principal
5. **Members:** search for the App Registration name (e.g., `sp-hd-notify-dev`)
6. Click **Review + assign**

### 5b. Key Vault Secrets Officer on the Key Vault

1. Go to the **Key Vault** (e.g., `kv-hd-notify-dev`)
2. Go to **Access control (IAM)** -> **Add role assignment**
3. **Role:** Key Vault Secrets Officer
4. **Assign access to:** User, group, or service principal
5. **Members:** search for the App Registration name (e.g., `sp-hd-notify-dev`)
6. Click **Review + assign**

---

## Step 6: Configure GitHub Environment

### 6a. Create the Environment

1. Go to the GitHub repo -> **Settings** -> **Environments** -> **New environment**
2. **Name:** `development`
3. Click **Configure environment**

### 6b. Add Environment Variables

Click **Add environment variable** for each:

| Variable | Value | Where to find it |
|----------|-------|-------------------|
| `AZURE_CLIENT_ID` | Application (client) ID | App Registration -> Overview |
| `AZURE_TENANT_ID` | Directory (tenant) ID | App Registration -> Overview |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID | Subscription -> Overview |
| `AZURE_RESOURCE_GROUP` | `rg-hd-notify-dev` | The name you chose in Step 1 |
| `AZURE_KEYVAULT_NAME` | `kv-hd-notify-dev` | The name you chose in Step 3 |

Then add service-specific variables:

**For Notify:**

| Variable | Value |
|----------|-------|
| `NOTIFY_FUNCTION_APP_NAME` | `func-hd-notify-dev` |

**For Notify.Worker:**

| Variable | Value |
|----------|-------|
| `NOTIFY_WORKER_CONTAINER_APP_NAME` | `ca-hd-notify-worker-dev` |
| `AZURE_CONTAINER_APPS_ENV` | `cae-hd-dev` |
| `ACR_REGISTRY` | `acrhdshareddev.azurecr.io` |

**For Pulse:**

| Variable | Value |
|----------|-------|
| `COLLECTOR_CONTAINER_APP_NAME` | `ca-hd-pulse-dev` |
| `AZURE_CONTAINER_APPS_ENV` | `cae-hd-dev` |
| `ACR_REGISTRY` | `acrhdshareddev.azurecr.io` |
| `COLLECTOR_KEYVAULT_SECRETS` | Newline-separated secret names |

See [azure-identity-and-secrets.md](azure-identity-and-secrets.md) for the full variable reference.

---

## Step 7: Test the Deployment

1. Go to the GitHub repo -> **Actions** tab
2. Select the **Deploy** workflow
3. Click **Run workflow**
4. Select the `development` environment
5. Click **Run workflow**
6. Watch the run — it should authenticate via OIDC, fetch secrets from Key Vault, and deploy to the Function App or Container App

If the run fails, check:
- **401/403 on Azure login:** Federated credential subject doesn't match (check repo name, environment name, org name in Step 4b)
- **403 on Key Vault:** App Registration missing Key Vault Secrets Officer role (Step 5b)
- **404 on resource group or app:** GitHub environment variable has wrong name (Step 6b)

---

## Checklist: New Service Provisioning

- [ ] Resource Group created
- [ ] Azure resources created (Function App / Container App / Storage / etc.)
- [ ] If containerized: shared `acrhdshared{env}` and `cae-hd-{env}` exist in `rg-hd-platform-{env}`
- [ ] Key Vault created with Azure RBAC enabled
- [ ] Key Vault secrets populated
- [ ] App Registration created with OIDC federated credential
- [ ] RBAC assigned (Contributor on RG + Key Vault Secrets Officer on KV)
- [ ] GitHub Environment created with all required variables
- [ ] Test deployment succeeds
- [ ] [azure-resource-inventory.md](azure-resource-inventory.md) updated (status -> Provisioned)
- [ ] [deployment-map.md](deployment-map.md) updated if new secrets or services were added

---

## How to Update This File

- **New resource type:** Add a section under Step 2 with portal instructions.
- **New service pattern:** Add service-specific values to the relevant steps.
- **Step changed:** Update the relevant step and the checklist if needed.
