resource "azurerm_databricks_workspace" "main" {
  name                = local.databricks_workspace_name
  resource_group_name = local.resource_group_name
  location            = var.location
  sku                 = "premium"
  depends_on          = [azurerm_resource_group.main]

  public_network_access_enabled         = false
  network_security_group_rules_required = "NoAzureDatabricksRules"

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = data.azurerm_virtual_network.main.id
    public_subnet_name                                   = data.azurerm_subnet.databricks_public.name
    private_subnet_name                                  = data.azurerm_subnet.databricks_private.name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.databricks_public_nsg_association.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.databricks_private_nsg_association.id
  }

  # Azure Databricks' enhanced_security_compliance feature only supports two compliance standards:
  # - HIPAA (Healthcare)
  # - PCI_DSS (Payment Card Industry)
  # 
  # It does not support CANADA_PROTECTED_B, which is a Canadian government security classification.
  # As of today, CANADA_PROTECTED_B cannot be configured through Terraform code, but it can be
  # manually enabled from the Azure Portal or Databricks workspace after deployment.
  # 
  # Once CANADA_PROTECTED_B is available as a supported compliance standard, uncomment the
  # enhanced_security_compliance block below and update compliance_security_profile_standards accordingly.
  # 
  # Reference: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_workspace
  # 
  # Note: The workspace is still secure with private network access, VNet injection, and no public IP.
  
  # enhanced_security_compliance {
  #   automatic_cluster_update_enabled      = true
  #   compliance_security_profile_enabled   = true
  #   compliance_security_profile_standards = ["HIPAA"]  # Only HIPAA or PCI_DSS are supported
  #   enhanced_security_monitoring_enabled  = true
  # }
}

resource "azurerm_databricks_access_connector" "ings" {
  name                = local.access_connector_ings_name
  resource_group_name = local.resource_group_name
  location            = var.location
  depends_on          = [azurerm_resource_group.main]
  identity {
    type = "SystemAssigned"
  }
  tags = local.common_tags
}

resource "azurerm_databricks_access_connector" "unity_catalog" {
  name                = local.access_connector_unity_catalog_name
  resource_group_name = local.resource_group_name
  location            = var.location
  depends_on          = [azurerm_resource_group.main]
  identity {
    type = "SystemAssigned"
  }
  tags = local.common_tags
} 