terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.54"
    }
  }

  # Backend configuration for Azure Storage Account
  # The state file key will be dynamically set based on environment
  # Use: terraform init -backend-config="key=databricks/${var.environment}.tfstate"
  backend "azurerm" {
    resource_group_name  = "contoso-auto-cc-terraform-rg-01"
    storage_account_name = "contosoautoterraformccsa01"
    container_name       = "tfstate"
    subscription_id      = "YOUR-STATE-SUBSCRIPTION-ID"
    # key will be set via backend-config during terraform init
  }
}

provider "azurerm" {
  features {}
  
  # Authentication will use environment variables:
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
  # These are set in azure-auth.env file
}

# Provider alias for POC subscription to access existing DNS zone
provider "azurerm" {
  alias           = "poc"
  subscription_id = "YOUR-POC-SUBSCRIPTION-ID"
  features {}
  
  # Authentication will use same environment variables
}

# Provider alias for Identity subscription to access existing private DNS zones
provider "azurerm" {
  alias           = "identity"
  subscription_id = "YOUR-IDENTITY-SUBSCRIPTION-ID"
  features {}
  
  # Authentication will use same environment variables
}