# Weekly Azure Cost Report - Logic App Standard Workflow

An automated weekly cost report that discovers Azure subscriptions, queries the Cost Management API, and emails a formatted HTML report to subscription owners.

**Blog Post:** [Building a Weekly Azure Cost Report with Logic App Standard](https://mohy.ai/blog/weekly-cost-report)

## What It Does

- Runs every Tuesday at 8 PM EST (configurable)
- Auto-discovers subscriptions matching a naming prefix (e.g., `sandbox-*`)
- Pulls 7-day cost data from the Azure Cost Management Query API
- Generates an HTML email with:
  - Total cost header with Azure-branded gradient
  - Daily cost breakdown table
  - Top 5 most expensive resources
  - Cost by Meter Category (service type)
- Emails the report to the subscription owner via a tag (`owner-email`)

## Architecture

```
Recurrence Trigger (Weekly)
    |
    v
[Key Vault] Get SP credentials (3 secrets)
    |
    v
Calculate 7-day date range
    |
    v
[ARM API] List subscriptions -> Filter by prefix + Enabled
    |
    v
For each subscription (Sequential):
    |-- Reset variables
    |-- Get subscription tags -> Extract owner-email
    |
    +-- If owner-email exists:
    |   |-- [4x PARALLEL] Cost Management API queries
    |   |-- Build daily table, top 5 resources, meter categories
    |   |-- Compose HTML email
    |   |-- Send via Office 365
    |
    +-- If no tag: skip
```

## Prerequisites

### 1. Service Principal

Create an App Registration in Entra ID with a client secret. Assign these RBAC roles on target subscriptions:

| Role | Purpose |
|------|---------|
| **Reader** | List subscriptions, read tags |
| **Cost Management Reader** | Query Cost Management API |

### 2. Key Vault Secrets

| Secret Name | Value |
|-------------|-------|
| `sp-tenant-id` | Your Azure AD Tenant ID |
| `sp-app-id` | Service Principal App (Client) ID |
| `sp-client-secret` | Service Principal Client Secret |

### 3. Subscription Tags

Each target subscription needs:

| Tag | Example |
|-----|---------|
| `owner-email` | `team-lead@yourcompany.com` |

Subscriptions without this tag are silently skipped.

### 4. Logic App Standard

- Create a **Logic App Standard** resource (not Consumption)
- Configure a **Key Vault Service Provider** connection named `keyVault-1`
- Configure an **Office 365 Outlook** managed API connection named `office365`

## Deployment

1. Create a new **Stateful** workflow in your Logic App Standard
2. Switch to **Code View**
3. Paste the contents of [`workflow.json`](./workflow.json)
4. Save
5. Verify connections in the **Connections** blade
6. Test: **Run Trigger** > **Recurrence**

## Customization

Search for `CUSTOMIZE` comments in `workflow.json` to find the key values to change:

| What | Where | Default |
|------|-------|---------|
| Subscription prefix | `Filter_-_Target_Subscriptions` | `sandbox-` |
| Email tag name | `Set_-_RecipientEmail` | `owner-email` |
| Schedule | `Recurrence` trigger | Tuesday 8 PM EST |
| Key Vault secrets | `Get_secret_-_*` actions | `sp-tenant-id`, `sp-app-id`, `sp-client-secret` |
| Email connection | `Send_email_-_Weekly_Cost_Report` | `office365` |

## Variables Reference

| Variable | Type | Purpose |
|----------|------|---------|
| `StartDate` | String | 7 days ago (yyyy-MM-dd) |
| `EndDate` | String | Today (yyyy-MM-dd) |
| `CurrentEmail` | String | Recipient email per subscription |
| `CurrentSubName` | String | Current subscription display name |
| `DailyCostHTML` | String | HTML table rows for daily cost |
| `TotalCost` | Float | Running total of 7-day cost |
| `Top5ResourceHTML` | String | HTML rows for top 5 resources |
| `MeterCategoryHTML` | String | HTML rows for service categories |

## Cost Management API Queries

The workflow makes 4 parallel API calls per subscription:

1. **Daily cost** (no grouping) - for the daily table and running total
2. **Daily cost by MeterCategory** - for stacked chart data
3. **Top 5 resources by ResourceId** - for the resource table
4. **Total by MeterCategory** - for the service category table

All queries use `ActualCost` type with a 7-day custom time period.

## Security Notes

- All Key Vault actions use `runtimeConfiguration.secureData` to hide credentials from run history
- All HTTP actions with authentication use `secureData` on inputs
- The Office 365 connector should use a service account or shared mailbox

## License

MIT - See [LICENSE](../LICENSE)
