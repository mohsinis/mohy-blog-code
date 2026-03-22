variable "environment" {
  description = "The environment to deploy (dev, stage, analytics, poc, test)."
  type        = string
  default     = "test"
  validation {
    condition     = contains(["dev", "stage", "analytics", "poc", "test"], var.environment)
    error_message = "Environment must be one of: dev, stage, analytics, poc, test."
  }
}

variable "location" {
  description = "The Azure region to deploy resources into."
  type        = string
  default     = "canadacentral"
}

variable "subscription_id" {
  description = "The Azure subscription ID to deploy resources into."
  type        = string
  default     = "YOUR-TEST-SUBSCRIPTION-ID"
}

# Dynamic naming using environment variable
locals {
  # Environment-specific naming
  env_suffix = var.environment

  # Common tags with dynamic environment
  common_tags = {
    ApplicationName = "Databricks"
    BusinessOwner   = "Your Business Owner"
    CreatedBy       = "Your Name"
    Environment     = title(var.environment)
    Region          = "Canada central"
    Sensitivity     = "Protected"
    DeploymentType  = "Terraform"
    Department      = "Your Department"
  }

  # Resource naming patterns
  resource_group_name        = "contoso-${var.environment}-databricks-rg-01"
  databricks_managed_rg_name = "contoso-${var.environment}-databricks-managed-rg-01"

  # Network naming
  vnet_name                      = "contoso-${var.environment}-cc-vnet-01"
  vnet_resource_group_name       = "contoso-${var.environment}-cc-vnet-rg-01"
  subnet_databricks_public_name  = "contoso-${var.environment}-databricks-public-snet-01"
  subnet_databricks_private_name = "contoso-${var.environment}-databricks-private-snet-01"
  subnet_pep_name                = "contoso-${var.environment}-pep-snet-01"

  # Storage account naming with environment abbreviations for character limit
  # Note: Storage account names must be 3-24 characters, lowercase letters and numbers only
  env_abbr = var.environment == "analytics" ? "anltcs" : var.environment
  storage_account_stg1_name = "contoso${local.env_abbr}ccdbwingstg001"
  storage_account_stg2_name = "contoso${local.env_abbr}ccdbwucstg001"

  # Databricks naming
  databricks_workspace_name           = "contoso-${var.environment}-databricks-wks-01"
  access_connector_ings_name          = "contoso-${var.environment}-ings-access-connector-wks"
  access_connector_unity_catalog_name = "contoso-${var.environment}-unity-catalog-access-connector-wks"

  # Container names (now environment-specific)
  container_test_name                    = var.environment
  container_raw_name                     = "raw"
  container_risk_resolution_name         = "risk-resolution"
  container_test_catalog_name            = "${var.environment}-catalog"
  container_risk_resolution_catalog_name = "risk-resolution-catalog"
  container_unitycatalog_name            = "unitycatalog"
} 