data "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  resource_group_name = local.vnet_resource_group_name
}

data "azurerm_subnet" "databricks_public" {
  name                 = local.subnet_databricks_public_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_virtual_network.main.resource_group_name
}

data "azurerm_subnet" "databricks_private" {
  name                 = local.subnet_databricks_private_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_virtual_network.main.resource_group_name
}

data "azurerm_subnet" "pep" {
  name                 = local.subnet_pep_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_virtual_network.main.resource_group_name
} 