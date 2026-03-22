# Azure Databricks with Private Endpoints - Terraform Deployment

A production-ready, multi-environment Terraform configuration for deploying Azure Databricks with full network isolation using private endpoints, VNet injection, and automated subnet delegation management.

**Blog Post:** [Deploying Azure Databricks with Private Endpoints using Terraform](https://mohy.ai/blog/databricks-private-endpoints)

## What It Deploys

- **Azure Databricks Workspace** (Premium SKU) with VNet injection and public access disabled
- **Two Storage Accounts** with HNS (Data Lake Gen2), private endpoints, and public access denied
- **Databricks Access Connectors** with System-Assigned Managed Identities for Unity Catalog and data ingestion
- **Private Endpoints** for Blob, DFS, and Databricks UI/API
- **Private DNS Zone** integration for automatic name resolution
- **Network Security Group** for Databricks subnets
- **IAM Role Assignments** (Storage Blob Data Contributor, Storage Queue Data Contributor)
- **Automated deployment script** with subnet delegation validation and fixing

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Subscription                    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Virtual Network                     │   │
│  │                                                  │   │
│  │  ┌──────────────┐  ┌──────────────┐            │   │
│  │  │  Databricks  │  │  Databricks  │            │   │
│  │  │   Public     │  │   Private    │            │   │
│  │  │   Subnet     │  │   Subnet     │            │   │
│  │  │  (delegated) │  │  (delegated) │            │   │
│  │  └──────┬───────┘  └──────┬───────┘            │   │
│  │         │                  │                     │   │
│  │         └────────┬─────────┘                     │   │
│  │                  │                               │   │
│  │         ┌────────▼────────┐                      │   │
│  │         │   Databricks    │                      │   │
│  │         │   Workspace     │◄── Private Endpoint  │   │
│  │         │   (Premium)     │                      │   │
│  │         └────────┬────────┘                      │   │
│  │                  │                               │   │
│  │    ┌─────────────┼─────────────┐                │   │
│  │    │             │             │                 │   │
│  │    ▼             ▼             ▼                 │   │
│  │ ┌──────┐   ┌──────┐   ┌──────────────┐         │   │
│  │ │ STG1 │   │ STG2 │   │ Private      │         │   │
│  │ │(INGS)│   │ (UC) │   │ Endpoint     │         │   │
│  │ │      │   │      │   │ Subnet       │         │   │
│  │ └──┬───┘   └──┬───┘   └──────────────┘         │   │
│  │    │           │                                 │   │
│  │    ▼           ▼                                 │   │
│  │  Private     Private                             │   │
│  │  Endpoints   Endpoints                           │   │
│  │  (Blob+DFS)  (Blob+DFS)                         │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  Private DNS Zones:                                     │
│  • privatelink.blob.core.windows.net                    │
│  • privatelink.dfs.core.windows.net                     │
│  • privatelink.azuredatabricks.net                      │
└─────────────────────────────────────────────────────────┘
```

## Multi-Environment Support

| Environment | Use Case |
|-------------|----------|
| `dev` | Development and experimentation |
| `test` | Testing and QA |
| `stage` | Pre-production staging |
| `analytics` | Production analytics workloads |
| `poc` | Proof of concept |

All resources auto-name based on environment: `contoso-{env}-databricks-*`

## Quick Start

```powershell
# 1. Copy and configure credentials
cp azure-auth.env.example azure-auth.env
# Edit azure-auth.env with your values

# 2. Initialize
.\deploy.ps1 -Environment dev -Action init

# 3. Preview
.\deploy.ps1 -Environment dev -Action plan

# 4. Deploy
.\deploy.ps1 -Environment dev -Action apply
```

## Prerequisites

- Azure subscription with Contributor access
- Existing VNet with 3 subnets (Databricks public, private, and PEP)
- Azure CLI and Terraform installed
- Service principal with appropriate permissions
- Azure Storage Account for Terraform state

## File Structure

```
├── provider.tf                 # Azure provider + backend config
├── variables.tf                # Environment variables + dynamic naming
├── resource_group.tf           # Resource group
├── network.tf                  # VNet/subnet data sources
├── databricks.tf               # Workspace + access connectors
├── storage.tf                  # Storage accounts, containers, IAM
├── private_endpoint.tf         # Private endpoints + DNS zones
├── nsg.tf                      # Network security groups
├── deploy.ps1                  # Automated deployment script
├── azure-pipelines.yml         # CI/CD pipeline definition
├── azure-auth.env.example      # Credential template
├── terraform.tfvars.example    # Variable template
└── backend-configs/            # Environment-specific state configs
```

## Security Features

- Public network access disabled on all resources
- Private endpoints for all data plane access
- VNet injection for Databricks clusters
- No public IPs on Databricks nodes
- Storage accounts deny all traffic by default
- Managed Identity-based access (no shared keys)
- NSG traffic control on Databricks subnets

## Customization

Search for `contoso` in the code and replace with your organization's naming prefix. Update `variables.tf` locals block with your naming conventions.

## License

MIT - See [LICENSE](../LICENSE)
