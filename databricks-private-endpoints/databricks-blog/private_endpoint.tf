# Use existing private DNS zones from Identity subscription
data "azurerm_private_dns_zone" "blob" {
  provider            = azurerm.identity
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "contoso-identity-cc-pdnsz-rg-01"
}

data "azurerm_private_dns_zone" "dfs" {
  provider            = azurerm.identity
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = "contoso-identity-cc-pdnsz-rg-01"
}

data "azurerm_private_dns_zone" "databricks_workspace" {
  provider            = azurerm.identity
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = "contoso-identity-cc-pdnsz-rg-01"
}


# Note: VNet links for private DNS zones are managed in the Identity subscription
# The private endpoints will automatically register DNS records in the existing zones
# Cross-subscription VNet linking should be managed separately if needed


resource "azurerm_private_endpoint" "stg1_blob" {
  name                = "contoso-${var.environment}-pep-${local.storage_account_stg1_name}-blob-01"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = data.azurerm_subnet.pep.id
  depends_on          = [azurerm_storage_container.test, azurerm_storage_container.raw, azurerm_storage_container.risk_resolution]
  tags                = local.common_tags

  private_service_connection {
    name                           = "stg1-blob-connection"
    private_connection_resource_id = azurerm_storage_account.stg1.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_private_endpoint" "stg2_blob" {
  name                = "contoso-${var.environment}-pep-${local.storage_account_stg2_name}-blob-01"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = data.azurerm_subnet.pep.id
  depends_on          = [azurerm_storage_container.test_catalog, azurerm_storage_container.risk_resolution_catalog, azurerm_storage_container.unitycatalog]
  tags                = local.common_tags

  private_service_connection {
    name                           = "stg2-blob-connection"
    private_connection_resource_id = azurerm_storage_account.stg2.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blob.id]
  }
}

# Private endpoints for DFS (Data Lake Storage Gen2) since HNS is enabled
resource "azurerm_private_endpoint" "stg1_dfs" {
  name                = "contoso-${var.environment}-pep-${local.storage_account_stg1_name}-dfs-01"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = data.azurerm_subnet.pep.id
  depends_on          = [azurerm_storage_container.test, azurerm_storage_container.raw, azurerm_storage_container.risk_resolution]
  tags                = local.common_tags

  private_service_connection {
    name                           = "stg1-dfs-connection"
    private_connection_resource_id = azurerm_storage_account.stg1.id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dfs-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.dfs.id]
  }
}

resource "azurerm_private_endpoint" "stg2_dfs" {
  name                = "contoso-${var.environment}-pep-${local.storage_account_stg2_name}-dfs-01"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = data.azurerm_subnet.pep.id
  depends_on          = [azurerm_storage_container.test_catalog, azurerm_storage_container.risk_resolution_catalog, azurerm_storage_container.unitycatalog]
  tags                = local.common_tags

  private_service_connection {
    name                           = "stg2-dfs-connection"
    private_connection_resource_id = azurerm_storage_account.stg2.id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dfs-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.dfs.id]
  }
}

resource "azurerm_private_endpoint" "databricks_workspace" {
  name                = "contoso-${var.environment}-pep-databricks-workspace-01"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = data.azurerm_subnet.pep.id
  depends_on          = [azurerm_databricks_workspace.main]
  tags                = local.common_tags

  private_service_connection {
    name                           = "databricks-workspace-connection"
    private_connection_resource_id = azurerm_databricks_workspace.main.id
    subresource_names              = ["databricks_ui_api"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "databricks-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.databricks_workspace.id]
  }
} 