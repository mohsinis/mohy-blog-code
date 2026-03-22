resource "azurerm_network_security_group" "databricks_nsg" {
  name                = "contoso-${var.environment}-databricks-nsg-01"
  location            = var.location
  resource_group_name = local.resource_group_name
  depends_on          = [azurerm_resource_group.main]
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "databricks_public_nsg_association" {
  network_security_group_id = azurerm_network_security_group.databricks_nsg.id
  subnet_id                 = data.azurerm_subnet.databricks_public.id
  
  # Note: During destroy, if you encounter errors about Network Intent Policies (NIPs),
  # run: .\cleanup-network-intent-policies.ps1 -Environment <env>
  # This is a known Azure Databricks issue with VNet injection
}

resource "azurerm_subnet_network_security_group_association" "databricks_private_nsg_association" {
  network_security_group_id = azurerm_network_security_group.databricks_nsg.id
  subnet_id                 = data.azurerm_subnet.databricks_private.id
  
  # Note: During destroy, if you encounter errors about Network Intent Policies (NIPs),
  # run: .\cleanup-network-intent-policies.ps1 -Environment <env>
  # This is a known Azure Databricks issue with VNet injection
} 