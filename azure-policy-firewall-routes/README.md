# Azure Policy: Firewall Route Enforcement with Defense-in-Depth

A set of four Azure Policy definitions and an initiative that enforce firewall routing across your Azure environment using a defense-in-depth strategy: auto-remediation, strict validation, deletion protection, and subnet compliance.

**Blog Post:** [Azure Policy Defense-in-Depth: Enforcing Firewall Routes That Can't Be Bypassed](https://mohy.ai/blog/azure-policy-firewall-routes)

## The Four Policies

| # | Policy | Effect | Purpose |
|---|--------|--------|---------|
| 1 | **Auto-Add Firewall Route** | `Modify` | Automatically injects the default route when a Route Table is created without it |
| 2 | **Deny Invalid Firewall Route** | `Deny` | Blocks creation/update of routes pointing `0.0.0.0/0` anywhere other than the firewall |
| 3 | **Deny Deletion of Firewall Route** | `DenyAction` | Prevents anyone from deleting the firewall default route |
| 4 | **Subnets Must Have Route Table** | `Deny` | Blocks subnet creation without an associated Route Table |

## Architecture

```
                    ┌──────────────────────────────────┐
                    │   Policy Initiative              │
                    │   "Firewall Route Enforcement"   │
                    └──────────┬───────────────────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
    ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐
    │  The Fixer  │    │  The Guard  │    │  The Lock   │
    │   (Modify)  │    │   (Deny)    │    │ (DenyAction)│
    │             │    │             │    │             │
    │ Auto-adds   │    │ Blocks bad  │    │ Prevents    │
    │ missing     │    │ route       │    │ deletion of │
    │ routes      │    │ configs     │    │ firewall    │
    └─────────────┘    └─────────────┘    │ route       │
                                          └─────────────┘
    ┌─────────────┐
    │  Subnet     │
    │  Enforcer   │
    │   (Deny)    │
    │             │
    │ No subnet   │
    │ without RT  │
    └─────────────┘
```

## Quick Start

### 1. Create the policy definitions

```bash
# Auto-Add
az policy definition create \
  --name "RT-Auto-Add-Firewall-Route" \
  --display-name "Auto-Add Firewall Route" \
  --rules policies/policy-auto-add.json \
  --params '{"firewallIP": {"type": "String"}}' \
  --mode All

# Deny Invalid
az policy definition create \
  --name "RT-Deny-Invalid-Firewall-Route" \
  --display-name "Deny Invalid Firewall Route" \
  --rules policies/policy-deny-invalid.json \
  --params '{"firewallIP": {"type": "String"}}' \
  --mode All

# Deny Deletion
az policy definition create \
  --name "RT-Deny-Deletion-Firewall-Route" \
  --display-name "Deny Deletion of Firewall Route" \
  --rules policies/policy-deny-delete.json \
  --mode All

# Subnet must have Route Table
az policy definition create \
  --name "Subnet-Must-Have-Route-Table" \
  --display-name "Subnets Must Have a Route Table" \
  --rules policies/policy-subnet-route-table.json \
  --mode All
```

### 2. Create the initiative

Update `initiative.json` with your policy definition IDs, then:

```bash
az policy set-definition create \
  --name "Firewall-Route-Enforcement" \
  --display-name "Firewall Route Enforcement Initiative" \
  --definitions policies/initiative.json
```

### 3. Assign the initiative

```bash
az policy assignment create \
  --name "Enforce-Firewall-Routes" \
  --policy-set-definition "Firewall-Route-Enforcement" \
  --scope "/subscriptions/YOUR-SUBSCRIPTION-ID" \
  --params '{"firewallIP": {"value": "YOUR-FIREWALL-IP"}}'
```

## Customization

Replace these values with your own:

| Placeholder | Description |
|------------|-------------|
| `YOUR-FIREWALL-IP` | Your Azure Firewall or NVA private IP (e.g., `10.0.0.4`) |
| `firewall-default-route` | The route name to protect (change in all policy JSONs) |
| `YOUR-SUBSCRIPTION-ID` | Target subscription or management group |

## Testing

| Scenario | Expected Result |
|----------|----------------|
| Create Route Table without firewall route | Route auto-added by Modify policy |
| Change default route to wrong IP | Blocked by Deny policy |
| Delete the firewall route | Blocked by DenyAction policy |
| Create subnet without Route Table | Blocked by Deny policy |

## License

MIT - See [LICENSE](../LICENSE)
